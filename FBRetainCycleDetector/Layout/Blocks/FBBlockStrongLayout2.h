/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#ifndef FBBlockStrongLayout2_h
#define FBBlockStrongLayout2_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSArray *_Nullable FBGetBlockStrongReferencesV2(void *_Nonnull block);

#ifdef __cplusplus
}
#endif

#endif /* FBBlockStrongLayout2_h */
