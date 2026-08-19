/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 Returns an array of id<FBObjectReference> objects that will have only those references
 that are retained by block.
 */
NSArray *_Nullable FBGetBlockStrongReferences(void *_Nonnull block);

BOOL FBObjectIsBlock(void *_Nullable object);

/**
 Process-wide count of capture slots that the block walker filtered out
 because the candidate pointer failed liveness checks. RCD scans on a
 background thread can race with capture teardown — bumping this counter
 (and silently skipping the slot) replaces a hard crash with a sampled
 signal. Read for diagnostics; resets only on process restart.
 */
uint64_t FBRCDFilteredCaptureSlotCount(void);

#ifdef __cplusplus
}
#endif
