/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#ifndef FBSwiftABIHelpers_h
#define FBSwiftABIHelpers_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FB_SWIFT_ABI_MAX_FIELDS 64
#define FB_SWIFT_ABI_MAX_CAPTURES 32

// Swift metadata kind constants — from swift/ABI/MetadataKind.def
#define SWIFT_KIND_HEAP_LOCAL_VARIABLE  0x400
#define LAST_ENUMERATED_METADATA_KIND   0x7FF

typedef enum {
  FBSwiftABIFieldKindStrongRef,
  FBSwiftABIFieldKindClosure,
} FBSwiftABIFieldKind;

typedef struct {
  const char *name;
  uintptr_t offset;
  FBSwiftABIFieldKind kind;
} FBSwiftABIFieldInfo;

/**
 Returns the number of interesting fields (strong refs + closures) declared
 by the given Swift class. Does NOT walk superclasses.
 Returns 0 for ObjC classes or if reflection metadata is stripped.
 */
int FBGetSwiftABIFields(const void *classMetadata,
                        FBSwiftABIFieldInfo *outFields,
                        int maxFields);

/**
 Returns strong captures from a Swift closure capture box.
 Uses the CaptureDescriptor (from HeapLocalVariableMetadata) to resolve
 each capture's mangled type name to type metadata, then classifies
 ownership deterministically. Weak (Xw) and unowned (Xo) captures are
 excluded. Returns 0 if no CaptureDescriptor is available.
 outOffsets receives the byte offsets within the box for each strong capture.
 */
int FBGetSwiftABICapturedStrongRefs(const void *captureBoxPtr,
                                    uintptr_t *outOffsets,
                                    int maxCaptures);

#ifdef __cplusplus
}
#endif

#endif /* FBSwiftABIHelpers_h */
