/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBObjectiveCGraphNode.h"

#import "FBObjectGraphConfiguration.h"
#import "FBObjectiveCGraphElement.h"
#import "FBObjectiveCObject.h"
#import "FBRetainCycleUtils.h"
#import "FBObjectiveCGraph.h"

@implementation FBObjectiveCGraphNode
{
  __weak id<FBObjectiveCGraphNodeDelegate> _delegate;
  FBObjectiveCGraphElement *_graphElement;
  NSHashTable<FBObjectiveCGraphNode *> *_outgoingReferences;
  NSHashTable<FBObjectiveCGraphNode *> *_incomingReferences;
}

- (instancetype)initWithGraphElement:(FBObjectiveCGraphElement *)graphElement
                            delegate:(id<FBObjectiveCGraphNodeDelegate>)delegate
{
  if (self = [super init]) {
    _graphElement = graphElement;
    _outgoingReferences = [NSHashTable weakObjectsHashTable];
    _incomingReferences = [NSHashTable weakObjectsHashTable];
    _delegate = delegate;
  }
  return self;
}

- (void)buildReferencesWithObjects:(NSSet<FBObjectiveCGraphElement *> *)retainedObjects
{
  for (FBObjectiveCGraphElement *graphElement in retainedObjects) {
    FBObjectiveCGraphNode *graphNode = [_delegate nodeForElement:graphElement];

    // Add incoming and outgoing references explicitly
    [graphNode addIncomingReference:self];
    [_outgoingReferences addObject:graphNode];
  }
}

- (void)addIncomingReference:(FBObjectiveCGraphNode *)node
{
  [_incomingReferences addObject:node];
}

- (id<NSFastEnumeration>)outgoingReferences
{
  return _outgoingReferences;
}

- (id<NSFastEnumeration>)incomingReferences
{
  return _incomingReferences;
}

- (FBObjectiveCGraphElement *)graphElement
{
  return _graphElement;
}

- (NSSet<FBObjectiveCGraphElement *> *)allRetainedObjects
{
  return [_graphElement allRetainedObjects];
}

@end
