/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBRetainCycleDetector.h"

@interface FBRetainCycleDetector ()

// Unit tests
- (NSArray *)_shiftToUnifiedCycle:(NSArray *)array;

@end
