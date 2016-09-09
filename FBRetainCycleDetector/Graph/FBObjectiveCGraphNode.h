/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBObjectiveCGraphElement.h"

@class FBObjectiveCGraphNode;

/**
 Represents a delegate that will be notified when a node in the graph is added or changed.
 */
@protocol FBObjectiveCGraphNodeDelegate <NSObject>

- (FBObjectiveCGraphNode *)nodeForElement:(FBObjectiveCGraphElement *)element;

@end

/**
 Wrapper around FBObjectiveCGraphElement.
 A FBObjectiveCGraphNode will represent an object with a set of outgoing references and a set of incoming references, as well as holding a reference
 to the FBObjectiveCGraphElement.
 */
@interface FBObjectiveCGraphNode : NSObject

/**
 Default initializer - Creates the node if the object doesn't already exist in the map.
 */
- (instancetype)initWithGraphElement:(FBObjectiveCGraphElement *)graphElement
                            delegate:(id<FBObjectiveCGraphNodeDelegate>)delegate;
/**
 Builds the outgoing and incoming references given all of the retained objects of a node.
 */
- (void)buildReferencesWithObjects:(NSSet<id> *)retainedObjects;
/**
 Setter to add an incoming reference.
 */
- (void)addIncomingReference:(FBObjectiveCGraphNode *)node;
/**
 Accessor to retrieve all objects objects this one is responsible for retaining.
 Currently returns a copy of the outgoing references.
*/
- (id<NSFastEnumeration>)outgoingReferences;
/**
 Accessor to retrieve all all objects that are responsible for retaining this one.
 Currently returns a copy of the incoming references.
 */
- (id<NSFastEnumeration>)incomingReferences;
/**
 Accessor to retrieve the actual object inside the node.
 */
- (FBObjectiveCGraphElement *)graphElement;
/**
 Accessor to retrieve all of the objects the object retains. It will be wrapped in an FBObjectiveCGraphElement
 */
- (NSSet<FBObjectiveCGraphElement *> *)allRetainedObjects;

@end
