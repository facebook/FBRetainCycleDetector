/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

/**
 We are mimicing Block structure based on Clang documentation:
 http://clang.llvm.org/docs/Block-ABI-Apple.html
 */

enum { // Flags from BlockLiteral
  BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
  BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
  BLOCK_IS_GLOBAL =         (1 << 28),
  BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
  BLOCK_HAS_SIGNATURE =     (1 << 30),
  BLOCK_HAS_EXTENDED_LAYOUT=(1 << 31)  // compiler
};

enum {
  BLOCK_LAYOUT_ESCAPE = 0, // N=0 halt, rest is non-pointer. N!=0 reserved.
  BLOCK_LAYOUT_NON_OBJECT_BYTES = 1,    // N bytes non-objects
  BLOCK_LAYOUT_NON_OBJECT_WORDS = 2,    // N words non-objects
  BLOCK_LAYOUT_STRONG           = 3,    // N words strong pointers
  BLOCK_LAYOUT_BYREF            = 4,    // N words byref pointers
  BLOCK_LAYOUT_WEAK             = 5,    // N words weak pointers
  BLOCK_LAYOUT_UNRETAINED       = 6,    // N words unretained pointers
  BLOCK_LAYOUT_UNKNOWN_WORDS_7  = 7,    // N words, reserved
  BLOCK_LAYOUT_UNKNOWN_WORDS_8  = 8,    // N words, reserved
  BLOCK_LAYOUT_UNKNOWN_WORDS_9  = 9,    // N words, reserved
  BLOCK_LAYOUT_UNKNOWN_WORDS_A  = 0xA,  // N words, reserved
  BLOCK_LAYOUT_UNUSED_B         = 0xB,  // unspecified, reserved
  BLOCK_LAYOUT_UNUSED_C         = 0xC,  // unspecified, reserved
  BLOCK_LAYOUT_UNUSED_D         = 0xD,  // unspecified, reserved
  BLOCK_LAYOUT_UNUSED_E         = 0xE,  // unspecified, reserved
  BLOCK_LAYOUT_UNUSED_F         = 0xF,  // unspecified, reserved
};

// Values for Block_byref->flags to describe __block variables
enum {
  // Byref refcount must use the same bits as Block_layout's refcount.
  // BLOCK_DEALLOCATING =      (0x0001),  // runtime
  // BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime

  BLOCK_BYREF_LAYOUT_MASK =       (0xf << 28), // compiler
  BLOCK_BYREF_LAYOUT_EXTENDED =   (  1 << 28), // compiler
  BLOCK_BYREF_LAYOUT_NON_OBJECT = (  2 << 28), // compiler
  BLOCK_BYREF_LAYOUT_STRONG =     (  3 << 28), // compiler
  BLOCK_BYREF_LAYOUT_WEAK =       (  4 << 28), // compiler
  BLOCK_BYREF_LAYOUT_UNRETAINED = (  5 << 28), // compiler

  BLOCK_BYREF_IS_GC =             (  1 << 27), // runtime

  BLOCK_BYREF_HAS_COPY_DISPOSE =  (  1 << 25), // compiler
  BLOCK_BYREF_NEEDS_FREE =        (  1 << 24), // runtime
};

struct BlockDescriptor {
  unsigned long int reserved;                // NULL
  unsigned long int size;
  // optional helper functions
  void (*copy_helper)(void *dst, void *src); // IFF (1<<25)
  void (*dispose_helper)(void *src);         // IFF (1<<25)
  const char *signature;                     // IFF (1<<30)
  const char *layout;                        // IFF (1<<31)
};

struct BlockLiteral {
  void *isa;  // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
  int flags;
  int reserved;
  void (*invoke)(void *, ...);
  struct BlockDescriptor *descriptor;
  // imported variables
};

struct Block_byref {
  void *isa;
  struct Block_byref *forwarding;
  volatile int32_t flags; // contains ref count
  uint32_t size;
  void (*keep_helper)(void *dst, void *src);
  void (*destory_helper)(void *src);
};
