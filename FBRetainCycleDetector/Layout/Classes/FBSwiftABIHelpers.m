/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "FBSwiftABIHelpers.h"
#include <string.h>

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

extern const void *swift_getTypeContextDescriptor(const void *metadata);

static inline const void *fbResolveRelativePointer(const void *base, int32_t offset) {
  if (offset == 0) return NULL;
  return (const void *)((uintptr_t)base + (intptr_t)offset);
}

/**
 Classify a field record by parsing its mangled type name.
 Returns 1 if the field is a strong object reference, 0 otherwise.

 Weak fields end with "Xw", unowned fields end with "Xo".
 Known value types (Int, Double, Float, Bool, String, UInt) are skipped.
 Fields containing symbolic references or existential type prefixes
 are treated as potential strong object references.
 */
static int fbIsStrongReference(const FBSwiftFieldRecord *record) {
  const void *base = &record->MangledTypeName;
  const uint8_t *mangled = (const uint8_t *)fbResolveRelativePointer(base, record->MangledTypeName);
  if (!mangled) return 0;

  uint8_t buf[256];
  int len = 0;
  int srcIdx = 0;
  int hasSymbolicRef = 0;

  while (len < 255) {
    uint8_t byte = mangled[srcIdx];
    if (byte == 0) break;
    buf[len++] = byte;
    if (byte >= 0x01 && byte <= 0x1F) {
      // Symbolic reference: 1 tag byte + 4-byte relative pointer
      hasSymbolicRef = 1;
      for (int k = 1; k <= 4 && len < 255; k++)
        buf[len++] = mangled[srcIdx + k];
      srcIdx += 5;
    } else {
      srcIdx += 1;
    }
  }
  buf[len] = 0;

  // Weak refs have mangled type suffix "Xw"
  if (len >= 2 && buf[len - 2] == 'X' && buf[len - 1] == 'w') return 0;
  // Unowned refs have mangled type suffix "Xo"
  if (len >= 2 && buf[len - 2] == 'X' && buf[len - 1] == 'o') return 0;

  // Known standard library value types: Si=Int, Sd=Double, Sf=Float,
  // Sb=Bool, SS=String, Su=UInt, SU=UnicodeScalar, Ss=Substring
  if (len == 2 && buf[0] == 'S') {
    char c = buf[1];
    if (c == 'i' || c == 'd' || c == 'f' || c == 'b' ||
        c == 'S' || c == 'u' || c == 'U' || c == 's')
      return 0;
  }

  // Contains a symbolic reference to a nominal type → potential object reference
  if (hasSymbolicRef) return 1;

  // Existential types (Any, AnyObject, protocol compositions) start with 'y'
  if (len >= 2 && buf[0] == 'y') return 1;

  return 0;
}

int FBGetSwiftABIStrongRefFields(const void *classMetadata,
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

    if (!fbIsStrongReference(record)) continue;

    const char *fieldName =
        (const char *)fbResolveRelativePointer(&record->FieldName, record->FieldName);
    uintptr_t fieldOffset = metaWords[classDesc->FieldOffsetVectorOffset + i];

    outFields[count].name = fieldName;
    outFields[count].offset = fieldOffset;
    count++;
  }

  return count;
}
