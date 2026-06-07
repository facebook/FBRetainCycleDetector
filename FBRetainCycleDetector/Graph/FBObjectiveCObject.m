/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBObjectiveCObject.h"

#import <objc/runtime.h>
#import <malloc/malloc.h>

#import "FBClassStrongLayout.h"
#import "FBObjectGraphConfiguration.h"
#import "FBObjectReference.h"
#import "FBRetainCycleUtils.h"

@implementation FBObjectiveCObject

- (NSSet *)allRetainedObjects
{
  // Pin the object alive for the entire method. For ObjC objects, reading
  // self.object via the weak property gives us a brief strong reference
  // that lives for the scope of strongObj. For pure Swift objects stored
  // via initWithUnsafeSwiftObject:, the raw _unsafeSwiftObject pointer
  // does NOT prevent deallocation. We must CFRetain the object to pin it
  // alive during traversal — without this, the object can be freed on
  // another thread between the malloc_zone_from_ptr check and subsequent
  // use, causing _objc_fatal in lookUpImpOrForward / objc_msgSend.
  __strong id strongObj = self.object;
  void *ptr;
  BOOL didRetainSwiftObject = NO;
  if (strongObj) {
    ptr = (__bridge void *)strongObj;
  } else {
    ptr = [self objectPtr];
    if (!ptr) {
      return nil;
    }
    // The pointer comes from _unsafeSwiftObject (raw, no prevent dealloc).
    // Validate it still lives in a valid malloc zone before retaining.
    if (!malloc_zone_from_ptr(ptr)) {
      return nil;
    }
    // Pin the Swift object alive for the duration of this method.
    // CFRetain works on any object with a valid isa pointer, including
    // pure Swift objects accessible via the ObjC runtime.
    CFRetain(ptr);
    didRetainSwiftObject = YES;
  }
  __unsafe_unretained id obj = (__bridge id)ptr;

  Class aCls = object_getClass(obj);
  if (!aCls) {
    if (didRetainSwiftObject) { CFRelease(ptr); }
    return nil;
  }

  NSArray *strongIvars = FBGetObjectStrongReferences(obj, self.configuration.layoutCache, self.configuration.shouldIncludeSwiftObjects, self.configuration.shouldUseSwiftABITraversal, self.configuration.shouldScanSwiftObjectMemory);

  NSMutableArray *retainedObjects = [[[super allRetainedObjects] allObjects] mutableCopy];

  for (id<FBObjectReference> ref in strongIvars) {
    id referencedObject = [ref objectReferenceFromObject:obj];

    if (referencedObject) {
      NSArray<NSString *> *namePath = [ref namePath];
      FBObjectiveCGraphElement *element = FBWrapObjectGraphElementWithContext(self,
                                                                              referencedObject,
                                                                              self.configuration,
                                                                              namePath);
      if (element) {
        [retainedObjects addObject:element];
      }
    }
  }

  if ([NSStringFromClass(aCls) hasPrefix:@"__NSCF"]) {
    /**
     If we are dealing with toll-free bridged collections, we are not guaranteed that the collection
     will hold only Objective-C objects. We are not able to check in runtime what callbacks it uses to
     retain/release (if any) and we could easily crash here.
     */
    if (didRetainSwiftObject) { CFRelease(ptr); }
    return [NSSet setWithArray:retainedObjects];
  }

  if (class_isMetaClass(aCls)) {
    // If it's a meta-class it can conform to following protocols,
    // but it would crash when trying enumerating
    if (didRetainSwiftObject) { CFRelease(ptr); }
    return nil;
  }

  if ([aCls conformsToProtocol:@protocol(NSFastEnumeration)]) {
    BOOL retainsKeys = [self _objectRetainsEnumerableKeys];
    BOOL retainsValues = [self _objectRetainsEnumerableValues];

    BOOL isKeyValued = NO;
    if ([aCls instancesRespondToSelector:@selector(objectForKey:)]) {
      isKeyValued = YES;
    }

    /**
     This codepath is prone to errors. When you enumerate a collection that can be mutated while enumeration
     we fall into risk of crash. To save ourselves from that we will catch such exception and try again.
     We should not try this endlessly, so at some point we will simply give up.
     */
    NSInteger tries = 10;
    for (NSInteger i = 0; i < tries; ++i) {
      // If collection is mutated we want to rollback and try again - let's keep refs in temporary set
      NSMutableSet *temporaryRetainedObjects = [NSMutableSet new];
      @try {
        for (id subobject in obj) {
          if (retainsKeys) {
            FBObjectiveCGraphElement *element = FBWrapObjectGraphElement(self, subobject, self.configuration);
            if (element) {
              [temporaryRetainedObjects addObject:element];
            }
          }
          if (isKeyValued && retainsValues) {
            FBObjectiveCGraphElement *element = FBWrapObjectGraphElement(self,
                                                                         [obj objectForKey:subobject],
                                                                         self.configuration);
            if (element) {
              [temporaryRetainedObjects addObject:element];
            }
          }
        }
      }
      @catch (NSException *exception) {
        // mutation happened, we want to try enumerating again
        continue;
      }

      // If we are here it means no exception happened and we want to break outer loop
      [retainedObjects addObjectsFromArray:[temporaryRetainedObjects allObjects]];
      break;
    }
  }

  if (didRetainSwiftObject) { CFRelease(ptr); }
  return [NSSet setWithArray:retainedObjects];
}

- (BOOL)_objectRetainsEnumerableValues
{
  if ([self.object respondsToSelector:@selector(valuePointerFunctions)]) {
    NSPointerFunctions *pointerFunctions = [self.object valuePointerFunctions];
    if (pointerFunctions.acquireFunction == NULL) {
      return NO;
    }
  }

  return YES;
}

- (BOOL)_objectRetainsEnumerableKeys
{
  if ([self.object respondsToSelector:@selector(pointerFunctions)]) {
    // NSHashTable and similar
    // If object shows what pointer functions are used, lets try to determine
    // if it's not retaining objects
    NSPointerFunctions *pointerFunctions = [self.object pointerFunctions];
    if (pointerFunctions.acquireFunction == NULL) {
      return NO;
    }
  }

  if ([self.object respondsToSelector:@selector(keyPointerFunctions)]) {
    NSPointerFunctions *pointerFunctions = [self.object keyPointerFunctions];
    if (pointerFunctions.acquireFunction == NULL) {
      return NO;
    }
  }

  return YES;
}

@end
