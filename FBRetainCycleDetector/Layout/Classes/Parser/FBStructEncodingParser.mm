/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBStructEncodingParser.h"

#import <unordered_set>

/**
 Intermediate struct object used inside the algorithm to pass some
 information when parsing nested structures.
 */
struct _StructParseResult {
  NSArray<FBParsedType *> *containedTypes;
  NSString *typeName;
};

static struct _StructParseResult _ParseStructEncodingWithScanner(NSScanner *scanner) {
  NSMutableArray *types = [NSMutableArray new];

  // Every struct starts with '{'
  __unused BOOL scannedCorrectly = [scanner scanString:@"{" intoString:nil];
  NSCAssert(scannedCorrectly, @"The first character of struct encoding should be {");

  // Parse name
  NSString *structTypeName = nil;
  [scanner scanUpToString:@"=" intoString:&structTypeName];
  [scanner scanString:@"=" intoString:nil];

  NSCharacterSet *literalEndingCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\"}"];

  while (![scanner scanString:@"}" intoString:nil]) {
    if ([scanner scanString:@"\"" intoString:nil]) {
      NSString *parseResult = nil;
      [scanner scanUpToString:@"\"" intoString:&parseResult];
      [scanner scanString:@"\"" intoString:nil];
      if (parseResult) {
        [types addObject:parseResult];
      }
    } else if ([scanner.string characterAtIndex:scanner.scanLocation] == '{') {
      // We do not want to consume '{' because we will call parser recursively
      NSUInteger locBefore = [scanner scanLocation];
      _StructParseResult parseResult = _ParseStructEncodingWithScanner(scanner);
      NSRange typeEncodingRange = NSMakeRange(locBefore, ([scanner scanLocation] - locBefore));
      NSString *nameFromBefore = [types lastObject];
      [types removeLastObject];
      FBParsedStruct *type = [[FBParsedStruct alloc] initWithName:nameFromBefore
                                                     typeEncoding:[scanner.string substringWithRange:typeEncodingRange]
                                                   structTypeName:parseResult.typeName
                                           typesContainedInStruct:parseResult.containedTypes];
      [types addObject:type];
    } else {
      // It's a type name (literal), let's advance until we find '"', or '}'
      NSString *parseResult = nil;
      [scanner scanUpToCharactersFromSet:literalEndingCharacters
                              intoString:&parseResult];

      NSString *nameFromBefore = nil;
      if ([[types lastObject] isKindOfClass:[NSString class]]) {
        // We have parsed some name
        nameFromBefore = [types lastObject];
        [types removeLastObject];
      }
      FBParsedType *type = [[FBParsedType alloc] initWithName:nameFromBefore
                                                 typeEncoding:parseResult];
      [types addObject:type];
    }
  }

  NSPredicate *filterPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject,
                                                                       NSDictionary<NSString *, id> *bindings) {
    if ([evaluatedObject isKindOfClass:[FBParsedType class]] ||
        [evaluatedObject isKindOfClass:[FBParsedStruct class]]) {
      return YES;
    }
    return NO;
  }];
  NSArray<FBParsedType *> *finalTypes = [types filteredArrayUsingPredicate:filterPredicate];

  return {
    .containedTypes = finalTypes,
    .typeName = structTypeName,
  };
}

FBParsedStruct *FBParseStructEncoding(NSString *structEncodingString) {
  return FBParseStructEncodingWithName(structEncodingString, nil);
}

FBParsedStruct *FBParseStructEncodingWithName(NSString *structEncodingString, NSString *structName) {
  struct _StructParseResult result = _ParseStructEncodingWithScanner([NSScanner scannerWithString:structEncodingString]);
  FBParsedStruct *outerStruct = [[FBParsedStruct alloc] initWithName:structName
                                                        typeEncoding:structEncodingString
                                                      structTypeName:result.typeName
                                              typesContainedInStruct:result.containedTypes];
  [outerStruct passTypePath:nil];
  return outerStruct;
}
