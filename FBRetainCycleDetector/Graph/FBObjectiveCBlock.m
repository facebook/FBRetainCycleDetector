/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBObjectiveCBlock.h"

#import <objc/runtime.h>

#import "FBBlockStrongLayout.h"
#import "FBBlockStrongRelationDetector.h"
#import "FBObjectGraphConfiguration.h"
#import "FBObjectiveCObject.h"
#import "FBRetainCycleUtils.h"

struct __attribute__((packed)) BlockLiteral {
  void *isa;
  int flags;
  int reserved;
  void *invoke;
  void *descriptor;
};

@implementation FBObjectiveCBlock

- (NSSet *)allRetainedObjects
{
  NSMutableArray *results = [[[super allRetainedObjects] allObjects] mutableCopy];

  // Grab a strong reference to the object, otherwise it can crash while doing
  // nasty stuff on deallocation
  __attribute__((objc_precise_lifetime)) id anObject = self.object;

  void *blockObjectReference = (__bridge void *)anObject;
  NSArray *allRetainedReferences = FBGetBlockStrongReferences(blockObjectReference);

  for (id object in allRetainedReferences) {
    FBObjectiveCGraphElement *element = FBWrapObjectGraphElement(self, object, self.configuration);
    if (element) {
      [results addObject:element];
    }
  }

  return [NSSet setWithArray:results];
}

/**
 * We want to add more information to blocks because they show up
 * in reports as MallocBlock and StackBlock which is not very informative.
 *
 * A block object is composed of:
 * - code: what should be executed, it's stored in the .TEXT section ;
 * - data: the variables that have been captured ;
 * - metadata: notably the function signature.
 *
 * We extract the address of the code, which can then be converted to a
 * human readable name given the debug symbol file.
 *
 * The symbol name contains the name of the function which allocated
 * the block, making is easier to track the piece of code participating
 * in the cycle. The symbolication must be done outside of this code
 * since it will require access to the debug symbols, not present at
 * runtime.
 *
 * Format: <<CLASSNAME:0xADDR>>
 */
- (NSString *)classNameOrNull
{
  NSString *className = NSStringFromClass([self objectClass]);
  if (!className) {
    className = @"(null)";
  }

  if (!self.configuration.shouldIncludeBlockAddress) {
    return className;
  }

  // Find the reference of the block object.
  __attribute__((objc_precise_lifetime)) id anObject = self.object;
  if ([anObject isKindOfClass:[FBBlockStrongRelationDetector class]]) {
    FBBlockStrongRelationDetector *blockObject = anObject;
    anObject = [blockObject forwarding];
  }
  void *blockObjectReference = (__bridge void *)anObject;
  if (!blockObjectReference) {
    return className;
  }

  // Extract the invocated block of code from the structure.
  const struct BlockLiteral *block = (struct BlockLiteral*) blockObjectReference;
  const void *blockCodePtr = block->invoke;

  return [NSString stringWithFormat:@"<<%@:0x%llx>>", className, (unsigned long long)blockCodePtr];
}

@end
