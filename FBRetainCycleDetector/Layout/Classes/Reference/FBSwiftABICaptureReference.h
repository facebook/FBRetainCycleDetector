/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBObjectReference.h"

/**
 A reference to an object captured strongly by a Swift closure.
 Follows the chain: owning object → closure field → context pointer →
 capture box → captured object at the given offset.
 */
@interface FBSwiftABICaptureReference : NSObject <FBObjectReference>

- (nonnull instancetype)initWithName:(nonnull NSString *)name
                  closureFieldOffset:(uintptr_t)closureFieldOffset
                    captureBoxOffset:(uintptr_t)captureBoxOffset;

@end
