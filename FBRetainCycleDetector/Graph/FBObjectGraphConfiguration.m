/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBObjectGraphConfiguration.h"

@implementation FBObjectGraphConfiguration

- (instancetype)initWithFilterBlocks:(NSArray<FBGraphEdgeFilterBlock> *)filterBlocks
                 shouldInspectTimers:(BOOL)shouldInspectTimers
                    transformerBlock:(nullable FBObjectiveCGraphElementTransformerBlock)transformerBlock
           shouldIncludeBlockAddress:(BOOL)shouldIncludeBlockAddress
           shouldIncludeSwiftObjects:(BOOL)shouldIncludeSwiftObjects
          shouldUseSwiftABITraversal:(BOOL)shouldUseSwiftABITraversal
{
  if (self = [super init]) {
    _filterBlocks = [filterBlocks copy];
    _shouldInspectTimers = shouldInspectTimers;
    _shouldIncludeBlockAddress = shouldIncludeBlockAddress;
    _shouldIncludeSwiftObjects = shouldIncludeSwiftObjects;
    _shouldUseSwiftABITraversal = shouldUseSwiftABITraversal;
    _transformerBlock = [transformerBlock copy];
    _layoutCache = [NSMutableDictionary new];
  }

  return self;
}

- (instancetype)initWithFilterBlocks:(NSArray<FBGraphEdgeFilterBlock> *)filterBlocks
                 shouldInspectTimers:(BOOL)shouldInspectTimers
                    transformerBlock:(nullable FBObjectiveCGraphElementTransformerBlock)transformerBlock
           shouldIncludeBlockAddress:(BOOL)shouldIncludeBlockAddress
           shouldIncludeSwiftObjects:(BOOL)shouldIncludeSwiftObjects
{
  return [self initWithFilterBlocks:filterBlocks
                shouldInspectTimers:shouldInspectTimers
                   transformerBlock:transformerBlock
          shouldIncludeBlockAddress:shouldIncludeBlockAddress
          shouldIncludeSwiftObjects:shouldIncludeSwiftObjects
         shouldUseSwiftABITraversal:NO];
}

- (instancetype)initWithFilterBlocks:(NSArray<FBGraphEdgeFilterBlock> *)filterBlocks
                 shouldInspectTimers:(BOOL)shouldInspectTimers
                    transformerBlock:(nullable FBObjectiveCGraphElementTransformerBlock)transformerBlock
           shouldIncludeBlockAddress:(BOOL)shouldIncludeBlockAddress
{
  return [self initWithFilterBlocks:filterBlocks
                shouldInspectTimers:shouldInspectTimers
                   transformerBlock:transformerBlock
          shouldIncludeBlockAddress:shouldIncludeBlockAddress
          shouldIncludeSwiftObjects:NO];
}

- (instancetype)initWithFilterBlocks:(NSArray<FBGraphEdgeFilterBlock> *)filterBlocks
                 shouldInspectTimers:(BOOL)shouldInspectTimers
                    transformerBlock:(nullable FBObjectiveCGraphElementTransformerBlock)transformerBlock
{
  return [self initWithFilterBlocks:filterBlocks
                shouldInspectTimers:shouldInspectTimers
                   transformerBlock:transformerBlock
          shouldIncludeBlockAddress:NO
          shouldIncludeSwiftObjects:NO
         shouldUseSwiftABITraversal:NO];
}

- (instancetype)initWithFilterBlocks:(NSArray<FBGraphEdgeFilterBlock> *)filterBlocks
                 shouldInspectTimers:(BOOL)shouldInspectTimers
{
  return [self initWithFilterBlocks:filterBlocks
                shouldInspectTimers:shouldInspectTimers
                   transformerBlock:nil];
}

- (instancetype)init
{
  // By default we are inspecting timers
  return [self initWithFilterBlocks:@[]
                shouldInspectTimers:YES];
}

@end
