/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBObjectiveCGraph.h"

#import "FBObjectiveCGraphElement.h"
#import "FBRetainCycleUtils.h"
#import "FBStandardGraphEdgeFilters.h"

@interface FBObjectiveCGraph () <FBObjectiveCGraphNodeDelegate>
@end

@implementation FBObjectiveCGraph
{
  NSMutableSet<FBObjectiveCGraphNode *> *_graphNodes;
  NSMapTable<FBObjectiveCGraphElement *, FBObjectiveCGraphNode *> *_elementNodeMap;
  FBObjectGraphConfiguration *_configuration;
}

+ (instancetype)sharedInstance
{
  static dispatch_once_t once;
  static FBObjectiveCGraph *graphInstance;

  dispatch_once(&once, ^{
    graphInstance = [FBObjectiveCGraph new];
  });
  return graphInstance;
}

- (id)init
{
  if (self = [super init]) {
    _configuration = [[FBObjectGraphConfiguration alloc] initWithFilterBlocks:FBGetStandardGraphEdgeFilters()
                                               shouldInspectTimers:NO];
  }
  return self;
}

- (FBObjectiveCGraphNode *)nodeForElement:(FBObjectiveCGraphElement *)element
{
  FBObjectiveCGraphNode *graphNode = [_elementNodeMap objectForKey:element];

  if (!graphNode) {
    graphNode = [[FBObjectiveCGraphNode alloc] initWithGraphElement:element
                                                           delegate:self];

    [_graphNodes addObject:graphNode];
    [_elementNodeMap setObject:graphNode forKey:element];
  }
  return graphNode;
}

- (void)buildGraphWithObjects:(NSSet<id> *)objects
{
  NSMutableArray *elementArray = [NSMutableArray new];

  for (id object in objects) {
    FBObjectiveCGraphElement *graphElement = FBWrapObjectGraphElement(nil, object, _configuration);
    if (graphElement) {
      [elementArray addObject:graphElement];
    }
  }

  [self buildGraph:elementArray];
}

- (void)buildGraph:(NSArray<FBObjectiveCGraphElement *> *)graphElements
{
  _elementNodeMap = [NSMapTable new];
  _graphNodes = [NSMutableSet new];

  for (FBObjectiveCGraphElement *graphElement in graphElements) {
    FBObjectiveCGraphNode *graphNode = [self nodeForElement:graphElement];

    // We may bump into objects that don't provide concrete implementations for functions we might call on them
    // As a result, we're going to go ahead and ignore them and continue
    @try {
      NSSet<FBObjectiveCGraphElement *> *retainedObjects = [graphNode allRetainedObjects];
      [graphNode buildReferencesWithObjects:retainedObjects];
    }
    @catch (NSException *e) {
      // No op
    }
  }
}

- (FBObjectGraphConfiguration *)graphConfiguration
{
  return _configuration;
}

- (NSSet<FBObjectiveCGraphNode *> *)graphNodes
{
  return [_graphNodes copy];
}

- (BOOL)isGraphConstructed
{
  return [_elementNodeMap count] > 0;
}

@end
