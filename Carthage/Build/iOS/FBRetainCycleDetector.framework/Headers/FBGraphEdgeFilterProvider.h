/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import "FBObjectiveCGraphElement.h"

typedef NS_ENUM(NSUInteger, FBGraphEdgeType) {
  FBGraphEdgeValid,
  FBGraphEdgeInvalid,
};

/**
 Every filter has to be of type FBGraphEdgeFilterBlock. Filter, given two object graph elements, it should decide,
 wether a reference between them should be filtered out or not.
 @see FBGetStandardGraphEdgeFilters()
 */
typedef FBGraphEdgeType (^FBGraphEdgeFilterBlock)(FBObjectiveCGraphElement *fromObject,
                                                  FBObjectiveCGraphElement *toObject);

/**
 @class FBGraphEdgeFilterProvider
 Can filter out different edges in object graph while doing retain cycle detection.
 The main use of this class is to gather filters that are instances of FBGraphEdgeFilterBlock
 block type that can answer the question, whether a relation from given object (fromObject) to
 second given object (toObject) should be considered as valid.

 Invalid relations would be the relations that we are guaranteed are going to be broken at some point.
 Be careful though, it's not so straightforward to tell if the relation will be broken *with 100%
 certainty*, and if you'll filter out something that could otherwise show retain cycle that leaks -
 it would never be caught by detector.

 For examples of what are the relations that will be broken at some point check FBStandardGraphEdgeFilters.mm
 */

@interface FBGraphEdgeFilterProvider : NSObject

/**
 Designated initializer.
 */
- (instancetype)initWithFilters:(NSArray<FBGraphEdgeFilterBlock> *)filters;

/**
 Given two objects this function will use all filters it was provided with to decide if
 the toObject reference should be ignored or not. If any filters fails, they will be dropped.
 @param fromObject Object graph element from which the reference comes
 @param toObject Object graph element to which the reference goes
 */
- (BOOL)shouldBreakGraphEdgeFromObject:(FBObjectiveCGraphElement *)fromObject
                              toObject:(FBObjectiveCGraphElement *)toObject;

@end
