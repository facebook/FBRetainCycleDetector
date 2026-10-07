/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBStandardGraphEdgeFilters.h"

#import <objc/runtime.h>

#import "FBObjectiveCGraphElement.h"
#import "FBRetainCycleDetector.h"

static BOOL FBClassIsSubclassOf(Class cls, Class parentCls) {
  Class c = cls;
  for (int depth = 0; c != Nil && depth < 128; depth++) {
    if ((uintptr_t)c & (sizeof(void *) - 1)) {
      return NO;
    }
    if (c == parentCls) {
      return YES;
    }
    c = class_getSuperclass(c);
  }
  return NO;
}

FBGraphEdgeFilterBlock FBFilterBlockWithObjectIvarRelation(Class aCls, NSString *ivarName) {
  return FBFilterBlockWithObjectToManyIvarsRelation(aCls, [NSSet setWithObject:ivarName]);
}

FBGraphEdgeFilterBlock FBFilterBlockWithObjectToManyIvarsRelation(Class aCls,
                                                                  NSSet<NSString *> *ivarNames) {
  return ^(FBObjectiveCGraphElement *fromObject,
           NSString *byIvar,
           Class toObjectOfClass){
    if (aCls &&
        FBClassIsSubclassOf([fromObject objectClass], aCls)) {
      // If graph element holds metadata about an ivar, it will be held in the name path, as early as possible
      if ([ivarNames containsObject:byIvar]) {
        return FBGraphEdgeInvalid;
      }
    }
    return FBGraphEdgeValid;
  };
}

FBGraphEdgeFilterBlock FBFilterBlockWithObjectIvarObjectRelation(Class fromClass, NSString *ivarName, Class toClass) {
  return ^(FBObjectiveCGraphElement *fromObject,
           NSString *byIvar,
           Class toObjectOfClass) {
    if (toClass &&
        FBClassIsSubclassOf(toObjectOfClass, toClass)) {
      return FBFilterBlockWithObjectIvarRelation(fromClass, ivarName)(fromObject, byIvar, toObjectOfClass);
    }
    return FBGraphEdgeValid;
  };
}

NSArray<FBGraphEdgeFilterBlock> *FBGetStandardGraphEdgeFilters() {
#if _INTERNAL_RCD_ENABLED
  NSMutableArray<FBGraphEdgeFilterBlock> *filters = [NSMutableArray new];

  Class viewClass = NSClassFromString(@"UIView");
  if (viewClass) {
    [filters addObject:FBFilterBlockWithObjectIvarRelation(viewClass, @"_subviewCache")];
  }

  Class heldActionClass = NSClassFromString(@"UIHeldAction");
  if (heldActionClass) {
    [filters addObject:FBFilterBlockWithObjectIvarRelation(heldActionClass, @"m_target")];
  }

  Class touchClass = NSClassFromString(@"UITouch");
  if (touchClass) {
    [filters addObject:FBFilterBlockWithObjectToManyIvarsRelation(touchClass,
                                                                 [NSSet setWithArray:@[@"_view",
                                                                                       @"_gestureRecognizers",
                                                                                       @"_window",
                                                                                       @"_warpedIntoView"]])];
  }

  Class transitionContextClass = NSClassFromString(@"_UIViewControllerOneToOneTransitionContext");
  if (transitionContextClass) {
    [filters addObject:FBFilterBlockWithObjectToManyIvarsRelation(transitionContextClass,
                                                                 [NSSet setWithArray:@[@"_toViewController",
                                                                                       @"_fromViewController"]])];
  }

  Class gestureRecognizerClass = NSClassFromString(@"UIGestureRecognizer");
  if (gestureRecognizerClass) {
    [filters addObject:FBFilterBlockWithObjectIvarRelation(gestureRecognizerClass, @"_gestureEnvironment")];
  }

  return filters;
#else
  return nil;
#endif // _INTERNAL_RCD_ENABLED
}
