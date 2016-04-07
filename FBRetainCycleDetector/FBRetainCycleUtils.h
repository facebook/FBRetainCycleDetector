/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class FBObjectGraphConfiguration;
@class FBObjectiveCGraphElement;

#ifdef __cplusplus
extern "C" {
#endif

/**
 Wrapper functions, for given object they will categorize it and create proper Graph Element subclass instance
 for it.
 */
FBObjectiveCGraphElement *FBWrapObjectGraphElementWithContext(id object,
                                                              FBObjectGraphConfiguration *configuration,
                                                              NSArray<NSString *> *namePath);
FBObjectiveCGraphElement *FBWrapObjectGraphElement(id object,
                                                   FBObjectGraphConfiguration *configuration);

#ifdef __cplusplus
}
#endif
