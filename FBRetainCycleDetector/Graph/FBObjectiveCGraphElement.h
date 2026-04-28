/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

@class FBObjectGraphConfiguration;

/**
 Base Graph Element representation. It carries some data about the object and should be overridden in subclass
 to provide references that subclass holds strongly (different for blocks, objects, other specializations).
 The Graph Element itself can only provide references from FBAssociationManager.
 */
@interface FBObjectiveCGraphElement : NSObject

/**
 Designated initializer.
 @param object Object this Graph Element will represent.
 @param configuration Provides detector's configuration that contains filters and options
 @param namePath Description of how the object was retrieved from it's parent. Check namePath property.
 */
- (nonnull instancetype)initWithObject:(nullable id)object
                         configuration:(nonnull FBObjectGraphConfiguration *)configuration
                              namePath:(nullable NSArray<NSString *> *)namePath;

/**
 @param object Object this Graph Element will represent.
 @param configuration Provides detector's configuration that contains filters and options
 */
- (nonnull instancetype)initWithObject:(nullable id)object
                         configuration:(nonnull FBObjectGraphConfiguration *)configuration;

/**
 Initializer for pure Swift objects that cannot be stored as __weak id.
 Stores the raw pointer without triggering ObjC ARC operations.
 */
- (nonnull instancetype)initWithUnsafeSwiftObject:(nonnull void *)objectPtr
                                    configuration:(nonnull FBObjectGraphConfiguration *)configuration
                                         namePath:(nullable NSArray<NSString *> *)namePath;


/**
 Name path that describes how this object was retrieved from its parent object by names
 (for example ivar names, struct references). For more check FBObjectReference protocol.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *namePath;
@property (nonatomic, weak, nullable) id object;
@property (nonatomic, readonly, nonnull) FBObjectGraphConfiguration *configuration;

/**
 Returns the raw object pointer. For ObjC objects, returns (__bridge void*)object.
 For pure Swift objects, returns the stored raw pointer. Safe for both paths.
 */
- (nullable void *)objectPtr;

/**
 Main accessor to all objects that the given object is retaining. Thread unsafe.

 @return NSSet of all objects this object is retaining.
 */
- (nullable NSSet *)allRetainedObjects;

/**
 @return address of the object represented by this element
 */
- (size_t)objectAddress;

/**
 @return class of the object
 */
- (nullable Class)objectClass;

/**
 @return a string of the classname or "(null)"
 */
- (nonnull NSString *)classNameOrNull;

/**
 @return return true if it is a swift type class"
 */
- (bool)isSwift;

@end
