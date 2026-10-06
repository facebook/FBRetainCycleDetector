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

@protocol FBObjectReferenceWithLayout;
@protocol FBObjectReference;

/** Selects one mutually exclusive strategy for discovering references held by Swift objects. */
typedef NS_ENUM(NSUInteger, FBSwiftReferenceDiscoveryMode) {
  FBSwiftReferenceDiscoveryModeDisabled,
  FBSwiftReferenceDiscoveryModeRuntimeIntrospection,
  FBSwiftReferenceDiscoveryModeABIMetadata,
  FBSwiftReferenceDiscoveryModeHeuristicMemoryScan,
};

/**
 @return An array of id<FBObjectReference> objects that will have only those references
 that are retained by the object. It also goes through parent classes.
 */
NSArray<id<FBObjectReference>> *_Nonnull FBGetObjectStrongReferences(id _Nullable obj,
                                                                     NSMutableDictionary<NSString*, NSArray<id<FBObjectReference>> *> *_Nullable layoutCache,
                                                                     FBSwiftReferenceDiscoveryMode swiftReferenceDiscoveryMode);

#ifdef __cplusplus
}
#endif
