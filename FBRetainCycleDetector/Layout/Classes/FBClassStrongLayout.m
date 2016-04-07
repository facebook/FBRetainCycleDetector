/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBClassStrongLayout.h"

#import <math.h>
#import <objc/runtime.h>

#import <UIKit/UIKit.h>

#import "FBIvarReference.h"
#import "FBObjectInStructReference.h"
#import "FBStructEncodingParser.h"

/**
 If we stumble upon a struct, we need to go through it and check if it doesn't retain some objects.
 */
static NSArray *FBGetReferencesForObjectsInStructEncoding(FBIvarReference *ivar, NSString *encoding) {
  NSMutableArray<FBObjectInStructReference *> *references = [NSMutableArray new];

  FBParsedStruct *parsedStruct = FBParseStructEncodingWithName(encoding,
                                                         ivar.name);
  NSArray<FBParsedType *> *types = [parsedStruct flattenTypes];

  ptrdiff_t offset = ivar.offset;

  for (FBParsedType *typeEncoding in types) {
    NSUInteger size, align;

    if ([typeEncoding.typeEncoding hasPrefix:@"^"]) {
      // It's a pointer, let's skip
      size = sizeof(void *);
      align = _Alignof(void *);
    } else {
      @try {
        const char *encodingString = [typeEncoding.typeEncoding UTF8String];
        NSGetSizeAndAlignment(encodingString,
                              &size,
                              &align);
      } @catch (NSException *e) {
        /**
         If we failed, we probably have C++ and ObjC cannot get it's size and alignment. We are skipping.
         If we would like to support it, we would need to derive size and alignment of type from the string.
         C++ does not have reflection so we can't really do that unless we create the mapping ourselves.
         */
        return nil;
      }
    }


    // The object must be aligned
    NSUInteger overAlignment = offset % align;
    NSUInteger whatsMissing = (overAlignment == 0) ? 0 : align - overAlignment;
    offset += whatsMissing;

    if ([typeEncoding.typeEncoding hasPrefix:@"@"]) {
      // The index that ivar layout will ask for is going to be aligned with pointer size

      // Prepare additional context
      NSString *typeEncodingName = typeEncoding.name;
      NSArray *namePath = typeEncoding.typePath;
      if (typeEncodingName) {
        namePath = [namePath arrayByAddingObject:typeEncodingName];
      }
      [references addObject:[[FBObjectInStructReference alloc] initWithIndex:(offset / sizeof(void *))
                                                                    namePath:namePath]];
    }

    offset += size;
  }

  return references;
}

NSArray<id<FBObjectReference>> *FBGetClassReferences(Class aCls) {
  NSMutableArray<id<FBObjectReference>> *result = [NSMutableArray new];

  unsigned int count;
  Ivar *ivars = class_copyIvarList(aCls, &count);

  for (unsigned int i = 0; i < count; ++i) {
    Ivar ivar = ivars[i];
    FBIvarReference *wrapper = [[FBIvarReference alloc] initWithIvar:ivar];

    if (wrapper.type == FBStructType) {
      NSString *encoding = @(ivar_getTypeEncoding(wrapper.ivar));
      NSArray<FBObjectInStructReference *> *references = FBGetReferencesForObjectsInStructEncoding(wrapper, encoding);

      [result addObjectsFromArray:references];
    } else {
      [result addObject:wrapper];
    }
  }
  free(ivars);

  return [result copy];
}

static NSIndexSet *FBGetLayoutAsIndexesForDescription(NSUInteger minimumIndex, const uint8_t *layoutDescription) {
  NSMutableIndexSet *interestingIndexes = [NSMutableIndexSet new];
  NSUInteger currentIndex = minimumIndex;

  while (*layoutDescription != '\x00') {
    int upperNibble = (*layoutDescription & 0xf0) >> 4;
    int lowerNibble = *layoutDescription & 0xf;

    // Upper nimble is for skipping
    currentIndex += upperNibble;

    // Lower nimble describes count
    [interestingIndexes addIndexesInRange:NSMakeRange(currentIndex, lowerNibble)];
    currentIndex += lowerNibble;

    ++layoutDescription;
  }

  return interestingIndexes;
}

static NSUInteger FBGetMinimumIvarIndex(__unsafe_unretained Class aCls) {
  NSUInteger minimumIndex = 1;
  unsigned int count;
  Ivar *ivars = class_copyIvarList(aCls, &count);

  if (count > 0) {
    Ivar ivar = ivars[0];
    ptrdiff_t offset = ivar_getOffset(ivar);
    minimumIndex = offset / (sizeof(void *));
  }

  free(ivars);

  return minimumIndex;
}

static NSArray<id<FBObjectReference>> *FBGetStrongReferencesForClass(Class aCls) {
  NSArray<id<FBObjectReference>> *ivars = [FBGetClassReferences(aCls) filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
    if ([evaluatedObject isKindOfClass:[FBIvarReference class]]) {
      FBIvarReference *wrapper = evaluatedObject;
      return wrapper.type != FBUnknownType;
    }
    return YES;
  }]];

  const uint8_t *fullLayout = class_getIvarLayout(aCls);

  if (!fullLayout) {
    return nil;
  }

  NSUInteger minimumIndex = FBGetMinimumIvarIndex(aCls);
  NSIndexSet *parsedLayout = FBGetLayoutAsIndexesForDescription(minimumIndex, fullLayout);

  NSArray<id<FBObjectReference>> *filteredIvars =
  [ivars filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<FBObjectReference> evaluatedObject,
                                                                           NSDictionary *bindings) {
    return [parsedLayout containsIndex:[evaluatedObject indexInIvarLayout]];
  }]];

  return filteredIvars;
}

NSArray<id<FBObjectReference>> *FBGetObjectStrongReferences(id obj) {
  NSMutableArray<id<FBObjectReference>> *array = [NSMutableArray new];

  __unsafe_unretained Class previousClass = nil;
  __unsafe_unretained Class currentClass = object_getClass(obj);

  while (previousClass != currentClass) {
    NSArray<id<FBObjectReference>> *ivars = FBGetStrongReferencesForClass(currentClass);
    [array addObjectsFromArray:ivars];

    previousClass = currentClass;
    currentClass = class_getSuperclass(currentClass);
  }

  return [array copy];
}
