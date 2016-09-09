/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBObjectGraphConfiguration.h"
#import "FBObjectiveCGraphNode.h"

/**
 Represents a cached graph. It holds references to the FBObjectiveCGraphNode elements within the graph.

 Note: This file and associated functionality has unpredicted behavior when used in runtime.
 Use only in halted state with lldb to guaranteee performance.
 Additionally - associated Chisel commands will only work with Xcode 7.3.1 and beyond (there is a known bug with the python script interpreter with 7.3)
 */
@interface FBObjectiveCGraph : NSObject<FBObjectiveCGraphNodeDelegate>

/**
 Returns a shared instance of the graph - at any point there shouldn't be more than one.
 */
+ (instancetype)sharedInstance;
/**
 Builds the graph given a set of objects.
 This will only build references out of the nodes provided (including building references to their adjacent nodes
 but no further than that).
 */
- (void)buildGraphWithObjects:(NSSet<id> *)objects;
/**
 Builds the graph given a set of graph elements.
 */
- (void)buildGraph:(NSArray<FBObjectiveCGraphElement *> *)graphElements;
/**
 Returns a node given a graph element.
 */
- (FBObjectiveCGraphNode *)nodeForElement:(FBObjectiveCGraphElement *)element;
/**
 Returns the current configuration for wrapping elements in the graph.
 */
- (FBObjectGraphConfiguration *)graphConfiguration;
/**
 Returns whether or not the graph has already been built.
 */
- (BOOL)isGraphConstructed;
/**
 Returns an array of FBObjectiveCGraphNodes that represents the graph.
 */
- (NSSet<FBObjectiveCGraphNode *> *)graphNodes;

@end
