/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBSwiftABIHelpers.h"
#import <Foundation/Foundation.h>
#include <string.h>
#include <malloc/malloc.h>
#include <mach/mach.h>

// Swift ABI struct layouts — derived from swift/ABI/Metadata.h

typedef struct {
  uint32_t Flags;
  int32_t Parent;
  int32_t Name;
  int32_t AccessFunction;
  int32_t FieldDescriptor;
  int32_t SuperclassType;
  uint32_t MetadataNegativeSizeInWords;
  uint32_t MetadataPositiveSizeInWords;
  uint32_t NumImmediateMembers;
  uint32_t NumFields;
  uint32_t FieldOffsetVectorOffset;
} FBSwiftClassDescriptor;

typedef struct {
  int32_t MangledTypeName;
  int32_t Superclass;
  uint16_t Kind;
  uint16_t FieldRecordSize;
  uint32_t NumFields;
} FBSwiftFieldDescriptor;

typedef struct {
  uint32_t Flags;
  int32_t MangledTypeName;
  int32_t FieldName;
} FBSwiftFieldRecord;

// Struct descriptor — same base layout as class descriptor but with
// NumFields and FieldOffsetVectorOffset at different offsets.
// Layout: Flags(+0) Parent(+4) Name(+8) AccessFunction(+12)
//         FieldDescriptor(+16) NumFields(+20) FieldOffsetVectorOffset(+24)
typedef struct {
  uint32_t Flags;
  int32_t Parent;
  int32_t Name;
  int32_t AccessFunction;
  int32_t FieldDescriptor;
  uint32_t NumFields;
  uint32_t FieldOffsetVectorOffset;
} FBSwiftStructDescriptor;

// CaptureDescriptor — from __swift5_capture / HeapLocalVariableMetadata
typedef struct {
  uint32_t NumCaptureTypes;
  uint32_t NumMetadataSources;
  uint32_t NumBindings;
  // CaptureTypeRecord[] follows
} FBCaptureDescriptor;

typedef struct {
  int32_t MangledTypeName; // relative pointer
} FBCaptureTypeRecord;

// Additional Swift metadata kind constants (SWIFT_KIND_HEAP_LOCAL_VARIABLE
// and LAST_ENUMERATED_METADATA_KIND are in the header)
#define SWIFT_KIND_STRUCT                 0x200
#define SWIFT_KIND_ENUM                   0x201
#define SWIFT_KIND_OPTIONAL               0x202
#define SWIFT_KIND_FOREIGN_CLASS          0x203
#define SWIFT_KIND_OPAQUE                 0x300
#define SWIFT_KIND_TUPLE                  0x301
#define SWIFT_KIND_FUNCTION               0x302
#define SWIFT_KIND_EXISTENTIAL            0x303
#define SWIFT_KIND_METATYPE               0x304
#define SWIFT_KIND_OBJC_CLASS_WRAPPER     0x305
#define SWIFT_KIND_EXISTENTIAL_METATYPE   0x306

extern const void *swift_getTypeContextDescriptor(const void *metadata);

// Resolves a mangled type name to its type metadata.
// The mangled bytes may contain symbolic references (0x01-0x1F).
// Uses C calling convention (unlike swift_getTypeByMangledNameInContext
// which uses Swift CC). environment and genericArgs may be NULL for
// non-generic types.
extern const void *swift_getTypeByMangledNameInEnvironment(
    const char *typeNameStart,
    size_t typeNameLength,
    const void * const *environment,
    const void * const *genericArgs);

static inline const void *fbResolveRelativePointer(const void *base, int32_t offset) {
  if (offset == 0) return NULL;
  return (const void *)((uintptr_t)base + (intptr_t)offset);
}

static int fbIsReadableAddr(const void *ptr) {
  if (!ptr) return 0;
  vm_address_t addr = (vm_address_t)ptr;
  vm_size_t size;
  vm_address_t regionAddr = addr;
  mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
  vm_region_basic_info_data_64_t info;
  memory_object_name_t object;
  kern_return_t ret = vm_region_64(
      mach_task_self(), &regionAddr, &size,
      VM_REGION_BASIC_INFO_64, (vm_region_info_64_t)&info,
      &count, &object);
  if (ret != KERN_SUCCESS) return 0;
  if (addr < regionAddr || addr >= regionAddr + size) return 0;
  return (info.protection & VM_PROT_READ) != 0;
}

/**
 Classify resolved type metadata.
 Returns:
   FBSwiftABIFieldKindStrongRef (0) — class, existential, ObjC wrapper
   FBSwiftABIFieldKindClosure   (1) — function type
   -1                               — value type, metatype, or unknown (skip)
 */
static int fbClassifyTypeMetadata(const void *typeMetadata) {
  if (!typeMetadata) return -1;

  uintptr_t kind = *(const uintptr_t *)typeMetadata;

  // Class: kind 0 (ObjC class) or > LAST_ENUMERATED_METADATA_KIND
  // (the kind field is actually the isa pointer for Swift classes)
  if (kind == 0 || kind > LAST_ENUMERATED_METADATA_KIND) {
    return FBSwiftABIFieldKindStrongRef;
  }

  switch (kind) {
  case SWIFT_KIND_FUNCTION:
    return FBSwiftABIFieldKindClosure;

  case SWIFT_KIND_EXISTENTIAL:
  case SWIFT_KIND_OBJC_CLASS_WRAPPER:
  case SWIFT_KIND_FOREIGN_CLASS:
    return FBSwiftABIFieldKindStrongRef;

  case SWIFT_KIND_OPTIONAL: {
    // Optional<T>: check if T is a reference type.
    // For generic nominal types, generic arguments follow the descriptor
    // pointer. Optional has 1 generic argument (T) at metadata[2].
    const void *wrappedType = ((const void **)typeMetadata)[2];
    return fbClassifyTypeMetadata(wrappedType);
  }

  case SWIFT_KIND_STRUCT: {
    // Check the Value Witness Table to determine if this struct is a
    // single-pointer wrapper around a reference-counted value (e.g.,
    // Array, Dictionary, Set, or any user struct wrapping a class ref).
    //
    // VWT pointer is at metadata[-1] (ABI-defined for value types).
    // VWT layout: 8 function pointers (64 bytes), then:
    //   +64: size (size_t)
    //   +80: flags (uint32_t, bit 16 = IsNonPOD)
    const void *vwt = ((const void **)typeMetadata)[-1];
    if (vwt) {
      size_t typeSize = *(const size_t *)((const char *)vwt + 64);
      uint32_t flags = *(const uint32_t *)((const char *)vwt + 80);
      int isNonPOD = (flags & 0x10000) != 0;

      if (typeSize == sizeof(void *) && isNonPOD) {
        // Pointer-sized struct with reference counting semantics.
        // The value at the field offset is a strong reference.
        return FBSwiftABIFieldKindStrongRef;
      }
    }
    return -1;
  }

  case SWIFT_KIND_ENUM:
  case SWIFT_KIND_TUPLE:
  case SWIFT_KIND_METATYPE:
  case SWIFT_KIND_EXISTENTIAL_METATYPE:
  case SWIFT_KIND_OPAQUE:
  default:
    return -1;
  }
}

/**
 Compute the raw byte length of a mangled type name, correctly stepping
 over symbolic reference entries (1 tag byte + 4 data bytes each).
 Also tracks the positions of the last two ASCII characters for
 ownership modifier detection.
 */
static int fbMangledNameRawLength(const uint8_t *mangled,
                                  int *outSecondLastAsciiPos,
                                  int *outLastAsciiPos) {
  int srcIdx = 0;
  int lastAsciiPos = -1;
  int secondLastAsciiPos = -1;

  while (mangled[srcIdx] != 0) {
    uint8_t byte = mangled[srcIdx];
    if (byte >= 0x01 && byte <= 0x1F) {
      // Symbolic reference: 1 tag byte + 4-byte relative pointer
      srcIdx += 5;
    } else {
      secondLastAsciiPos = lastAsciiPos;
      lastAsciiPos = srcIdx;
      srcIdx++;
    }
  }

  *outSecondLastAsciiPos = secondLastAsciiPos;
  *outLastAsciiPos = lastAsciiPos;
  return srcIdx;
}

/**
 Resolve a mangled type name to type metadata and classify it.
 Optionally returns the resolved metadata pointer via outMetadata.

 Returns:
   FBSwiftABIFieldKindStrongRef — strong object reference
   FBSwiftABIFieldKindClosure   — function/closure type
   -2                            — weak or unowned (skip)
   -1                            — value type or unresolvable (skip)
 */
static int fbResolveAndClassifyType(const void *mangledTypeNameField,
                                    int32_t relativeOffset,
                                    const void **outMetadata) {
  if (outMetadata) *outMetadata = NULL;

  const uint8_t *mangled =
      (const uint8_t *)fbResolveRelativePointer(mangledTypeNameField, relativeOffset);
  if (!mangled) return -1;

  int secondLastAsciiPos, lastAsciiPos;
  int rawLen = fbMangledNameRawLength(mangled, &secondLastAsciiPos, &lastAsciiPos);
  if (rawLen == 0) return -1;

  // Check for weak (Xw) and unowned (Xo) ownership modifiers.
  if (lastAsciiPos >= 0 && secondLastAsciiPos >= 0) {
    uint8_t last = mangled[lastAsciiPos];
    uint8_t secondLast = mangled[secondLastAsciiPos];
    if (secondLast == 'X' && last == 'w') return -2;
    if (secondLast == 'X' && last == 'o') return -2;
  }

  const void *typeMetadata = swift_getTypeByMangledNameInEnvironment(
      (const char *)mangled, (size_t)rawLen, NULL, NULL);
  if (!typeMetadata) return -1;

  if (outMetadata) *outMetadata = typeMetadata;
  return fbClassifyTypeMetadata(typeMetadata);
}

/**
 Recursively walk a struct's fields and collect strong references.
 baseOffset is the byte offset of this struct within the enclosing object.
 Returns the number of strong ref fields added to outFields.
 */
/**
 Get the byte offset of field i within a struct.
 If the metadata has a field offset vector, read from it.
 Otherwise, compute by walking previous fields' VWT sizes + alignment.
 */
static int fbGetStructFieldOffset(const FBSwiftStructDescriptor *structDesc,
                                  const uintptr_t *metaWords,
                                  uint32_t fieldIndex,
                                  uintptr_t *outOffset) {
  if (structDesc->FieldOffsetVectorOffset != 0) {
    // Read from the field offset vector in the struct metadata.
    // FieldOffsetVectorOffset is in pointer-sized words from the metadata start,
    // but the stored field offsets are uint32_t (not uintptr_t) per Swift ABI.
    const uint32_t *fieldOffsets =
        (const uint32_t *)(metaWords + structDesc->FieldOffsetVectorOffset);
    *outOffset = fieldOffsets[fieldIndex];
    return 1;
  }

  // FieldOffsetVectorOffset == 0 means no vector is stored (fixed-layout struct).
  // This shouldn't happen for structs with reflection metadata in debug builds,
  // but return failure to be safe.
  return 0;
}

static int fbGetStructStrongRefFields(const void *structMetadata,
                                      uintptr_t baseOffset,
                                      FBSwiftABIFieldInfo *outFields,
                                      int maxFields) {
  if (!structMetadata || maxFields <= 0) return 0;

  const void *descriptor = swift_getTypeContextDescriptor(structMetadata);
  if (!descriptor) return 0;

  const FBSwiftStructDescriptor *structDesc = (const FBSwiftStructDescriptor *)descriptor;
  if (structDesc->NumFields == 0) return 0;
  if (structDesc->FieldDescriptor == 0) return 0;

  const FBSwiftFieldDescriptor *fieldDesc =
      (const FBSwiftFieldDescriptor *)fbResolveRelativePointer(
          &structDesc->FieldDescriptor, structDesc->FieldDescriptor);
  if (!fieldDesc) return 0;

  const uintptr_t *metaWords = (const uintptr_t *)structMetadata;
  const FBSwiftFieldRecord *records =
      (const FBSwiftFieldRecord *)((const char *)fieldDesc + sizeof(FBSwiftFieldDescriptor));

  int count = 0;
  for (uint32_t i = 0; i < structDesc->NumFields && count < maxFields; i++) {
    const FBSwiftFieldRecord *record = &records[i];

    uintptr_t fieldOffset = 0;
    if (!fbGetStructFieldOffset(structDesc, metaWords, i, &fieldOffset)) continue;

    const void *fieldTypeMetadata = NULL;
    int kind = fbResolveAndClassifyType(&record->MangledTypeName,
                                        record->MangledTypeName,
                                        &fieldTypeMetadata);
    if (kind < 0) {
      if (fieldTypeMetadata && kind == -1) {
        uintptr_t fieldKind = *(const uintptr_t *)fieldTypeMetadata;
        if (fieldKind == SWIFT_KIND_STRUCT) {
          int added = fbGetStructStrongRefFields(fieldTypeMetadata,
                                                  baseOffset + fieldOffset,
                                                  outFields + count,
                                                  maxFields - count);
          count += added;
        }
      }
      continue;
    }

    const char *fieldName =
        (const char *)fbResolveRelativePointer(&record->FieldName, record->FieldName);

    outFields[count].name = fieldName;
    outFields[count].offset = baseOffset + fieldOffset;
    outFields[count].kind = (FBSwiftABIFieldKind)kind;
    count++;
  }

  return count;
}

int FBGetSwiftABIFields(const void *classMetadata,
                        FBSwiftABIFieldInfo *outFields,
                        int maxFields) {
  if (!classMetadata) return 0;

  const void *descriptor = swift_getTypeContextDescriptor(classMetadata);
  if (!descriptor) return 0;

  const FBSwiftClassDescriptor *classDesc = (const FBSwiftClassDescriptor *)descriptor;

  if (classDesc->NumFields == 0 || classDesc->FieldOffsetVectorOffset == 0) return 0;
  if (classDesc->FieldDescriptor == 0) return 0;

  const FBSwiftFieldDescriptor *fieldDesc =
      (const FBSwiftFieldDescriptor *)fbResolveRelativePointer(
          &classDesc->FieldDescriptor, classDesc->FieldDescriptor);
  if (!fieldDesc) return 0;

  const uintptr_t *metaWords = (const uintptr_t *)classMetadata;
  const FBSwiftFieldRecord *records =
      (const FBSwiftFieldRecord *)((const char *)fieldDesc + sizeof(FBSwiftFieldDescriptor));

  int count = 0;
  for (uint32_t i = 0; i < classDesc->NumFields && count < maxFields; i++) {
    const FBSwiftFieldRecord *record = &records[i];

    const void *fieldTypeMetadata = NULL;
    int kind = fbResolveAndClassifyType(&record->MangledTypeName,
                                        record->MangledTypeName,
                                        &fieldTypeMetadata);

    uintptr_t fieldOffset = metaWords[classDesc->FieldOffsetVectorOffset + i];

    if (kind < 0) {
      // Check if this is a struct that we should recurse into
      if (fieldTypeMetadata && kind == -1) {
        uintptr_t fieldKind = *(const uintptr_t *)fieldTypeMetadata;
        if (fieldKind == SWIFT_KIND_STRUCT) {
          int added = fbGetStructStrongRefFields(fieldTypeMetadata,
                                                  fieldOffset,
                                                  outFields + count,
                                                  maxFields - count);
          count += added;
        }
      }
      continue;
    }

    const char *fieldName =
        (const char *)fbResolveRelativePointer(&record->FieldName, record->FieldName);

    outFields[count].name = fieldName;
    outFields[count].offset = fieldOffset;
    outFields[count].kind = (FBSwiftABIFieldKind)kind;
    count++;
  }

  return count;
}

int FBGetSwiftABICapturedStrongRefs(const void *captureBoxPtr,
                                    uintptr_t *outOffsets,
                                    int maxCaptures) {
  if (!captureBoxPtr) return 0;
  if ((uintptr_t)captureBoxPtr & 0x7) return 0;

  size_t boxSize = malloc_size(captureBoxPtr);
  if (boxSize == 0) return 0;

  const void *metadata = *(const void **)captureBoxPtr;
  if (!metadata) return 0;

  uint64_t kind = *(const uint64_t *)metadata;
  if (kind != SWIFT_KIND_HEAP_LOCAL_VARIABLE) return 0;

  uint32_t offsetToFirstCapture = *(const uint32_t *)((const char *)metadata + 8);
  if (offsetToFirstCapture < 16 || (size_t)offsetToFirstCapture >= boxSize) {
    offsetToFirstCapture = 16;
  }

  // HeapLocalVariableMetadata layout (arm64):
  //   +0:  kind (8 bytes, value = 0x400)
  //   +8:  OffsetToFirstCapture (uint32_t)
  //   +12: padding (4 bytes)
  //   +16: CaptureDescription (pointer to CaptureDescriptor)
  //
  // The CaptureDescriptor describes each capture's type via mangled names.
  // We resolve each mangled name to type metadata to deterministically
  // classify capture ownership.
  const void *captureDescPtr = NULL;
  const void *captureDescAddr = (const char *)metadata + 16;
  if (fbIsReadableAddr(captureDescAddr)) {
    captureDescPtr = *(const void **)captureDescAddr;
  }

  if (captureDescPtr && fbIsReadableAddr(captureDescPtr)) {
    const FBCaptureDescriptor *desc = (const FBCaptureDescriptor *)captureDescPtr;
    uint32_t numCaptures = desc->NumCaptureTypes;

    if (numCaptures > 0 && numCaptures <= FB_SWIFT_ABI_MAX_CAPTURES) {
      const FBCaptureTypeRecord *records =
          (const FBCaptureTypeRecord *)((const char *)desc + sizeof(FBCaptureDescriptor));

      int count = 0;
      for (uint32_t i = 0; i < numCaptures && count < maxCaptures; i++) {
        size_t captureOffset = (size_t)offsetToFirstCapture + i * sizeof(void *);
        if (captureOffset + sizeof(void *) > boxSize) break;

        // Resolve the capture's mangled type to metadata and classify
        int ownership = fbResolveAndClassifyType(&records[i].MangledTypeName,
                                                 records[i].MangledTypeName,
                                                 NULL);
        if (ownership < 0 || ownership != FBSwiftABIFieldKindStrongRef) continue;

        // Safety: validate the value at this offset is a valid heap pointer
        const void *val = *(const void **)((const char *)captureBoxPtr + captureOffset);
        if (!val) continue;
        if ((uintptr_t)val & 0x7) continue;
        if (malloc_size(val) == 0) continue;

        outOffsets[count] = captureOffset;
        count++;
      }

      return count;
    }
  }

  // No CaptureDescription available (runtime-created boxes).
  // Without capture type metadata we cannot deterministically classify
  // captures, so return 0.
  return 0;
}
