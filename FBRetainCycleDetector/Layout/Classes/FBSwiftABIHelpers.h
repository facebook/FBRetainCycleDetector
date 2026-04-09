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

typedef struct {
  const char *name;
  uintptr_t offset;
} FBSwiftABIFieldInfo;

/**
 Returns the number of strong reference fields declared by the given Swift class.
 Does NOT walk superclasses — the caller handles the class hierarchy.
 Results are written to outFields, up to maxFields entries.
 Returns 0 for ObjC classes or if reflection metadata is stripped.
 */
int FBGetSwiftABIStrongRefFields(const void *classMetadata,
                                 FBSwiftABIFieldInfo *outFields,
                                 int maxFields);

#ifdef __cplusplus
}
#endif

#endif /* FBSwiftABIHelpers_h */
