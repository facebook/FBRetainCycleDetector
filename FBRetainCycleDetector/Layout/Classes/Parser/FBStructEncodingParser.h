/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import "FBParsedStruct.h"
#import "FBParsedType.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 This function will parse a struct encoding from an ivar, and return an FBParsedStruct instance.
 Check FBParsedStruct to learn more on how to interact with it.

 FBParseStructEncoding assumes the string passed to it will be a proper struct encoding.
 It will not work with encodings provided by @encode() because they do not add names.
 It will work with encodings provided by ivars (ivar_getTypeEncoding)
 */
FBParsedStruct *_Nonnull FBParseStructEncoding(NSString *_Nonnull structEncodingString);

/**
 You can provide name for root struct you are passing. The name will be then used
 in typePath (check out FBParsedType for details).
 The name here can be for example a name of an ivar with this struct.
 */
FBParsedStruct *_Nonnull FBParseStructEncodingWithName(NSString *_Nonnull structEncodingString,
                                                       NSString *_Nullable structName);

#ifdef __cplusplus
}
#endif
