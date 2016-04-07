/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBRetainCycleUtils.h"

#import <objc/runtime.h>

#import "FBBlockStrongLayout.h"
#import "FBClassStrongLayout.h"
#import "FBObjectiveCBlock.h"
#import "FBObjectiveCGraphElement.h"
#import "FBObjectiveCNSCFTimer.h"
#import "FBObjectiveCObject.h"
#import "FBObjectGraphConfiguration.h"

FBObjectiveCGraphElement *FBWrapObjectGraphElementWithContext(id object,
                                                              FBObjectGraphConfiguration *configuration,
                                                              NSArray<NSString *> *namePath) {
  if (FBObjectIsBlock((__bridge void *)object)) {
    return [[FBObjectiveCBlock alloc] initWithObject:object
                                      configuration:configuration
                                            namePath:namePath];
  } else {
    if ([object_getClass(object) isSubclassOfClass:[NSTimer class]] &&
        configuration.shouldInspectTimers) {
      return [[FBObjectiveCNSCFTimer alloc] initWithObject:object
                                             configuration:configuration
                                                  namePath:namePath];
    } else {
      return [[FBObjectiveCObject alloc] initWithObject:object
                                          configuration:configuration
                                               namePath:namePath];
    }
  }
}

FBObjectiveCGraphElement *FBWrapObjectGraphElement(id object,
                                                   FBObjectGraphConfiguration *configuration) {
  return FBWrapObjectGraphElementWithContext(object, configuration, nil);
}
