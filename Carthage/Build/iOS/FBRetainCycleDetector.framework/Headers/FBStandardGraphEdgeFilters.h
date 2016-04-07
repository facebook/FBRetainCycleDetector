/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import "FBGraphEdgeFilterProvider.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 Standard filters mostly filters excluding some UIKit references we have caught during testing on some apps.
 */
NSArray<FBGraphEdgeFilterBlock> *FBGetStandardGraphEdgeFilters();

/**
 Helper functions for some typical patterns.
 */
FBGraphEdgeFilterBlock FBFilterBlockWithObjectIvarRelation(Class aCls, NSString *ivarName);
FBGraphEdgeFilterBlock FBFilterBlockWithObjectToManyIvarsRelation(Class aCls,
                                                                  NSSet<NSString *> *ivarNames);
FBGraphEdgeFilterBlock FBFilterBlockWithObjectIvarObjectRelation(Class fromClass,
                                                                 NSString *ivarName,
                                                                 Class toClass);

#ifdef __cplusplus
}
#endif
