/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 We are mimicing Block structure based on libclouse project:
 https://opensource.apple.com/source/libclosure/libclosure-74/Block_private.h
 */

#ifndef _BLOCK_PRIVATE_H_
#define _BLOCK_PRIVATE_H_

struct Block_byref;

typedef void(*BlockCopyFunction)(void *, const void *);
typedef void(*BlockDisposeFunction)(const void *);
typedef void(*BlockInvokeFunction)(void *, ...);
typedef void(*BlockByrefKeepFunction)(struct Block_byref *, struct Block_byref *);
typedef void(*BlockByrefDestroyFunction)(struct Block_byref *);

// Values for Block_layout->flags to describe block objects
enum {
  BLOCK_DEALLOCATING =      (0x0001),  // runtime
  BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime
  BLOCK_NEEDS_FREE =        (1 << 24), // runtime
  BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // compiler
  BLOCK_HAS_CTOR =          (1 << 26), // compiler: helpers have C++ code
  BLOCK_IS_GC =             (1 << 27), // runtime
  BLOCK_IS_GLOBAL =         (1 << 28), // compiler
  BLOCK_USE_STRET =         (1 << 29), // compiler: undefined if !BLOCK_HAS_SIGNATURE
  BLOCK_HAS_SIGNATURE  =    (1 << 30), // compiler
  BLOCK_HAS_EXTENDED_LAYOUT=(1 << 31)  // compiler
};

#define BLOCK_DESCRIPTOR_1 1
struct Block_descriptor_1 {
  uintptr_t reserved;
  uintptr_t size;
};

#define BLOCK_DESCRIPTOR_2 1
struct Block_descriptor_2 {
  // requires BLOCK_HAS_COPY_DISPOSE
  BlockCopyFunction copy;
  BlockDisposeFunction dispose;
};

#define BLOCK_DESCRIPTOR_3 1
struct Block_descriptor_3 {
  // requires BLOCK_HAS_SIGNATURE
  const char *signature;
  const char *layout;     // contents depend on BLOCK_HAS_EXTENDED_LAYOUT
};

struct Block_layout {
  void *isa;
  volatile int32_t flags; // contains ref count
  int32_t reserved;
  BlockInvokeFunction invoke;
  struct Block_descriptor_1 *descriptor;
  // imported variables
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

struct Block_byref {
  void *isa;
  struct Block_byref *forwarding;
  volatile int32_t flags; // contains ref count
  uint32_t size;
};

struct Block_byref_2 {
  // requires BLOCK_BYREF_HAS_COPY_DISPOSE
  BlockByrefKeepFunction byref_keep;
  BlockByrefDestroyFunction byref_destroy;
};

struct Block_byref_3 {
  // requires BLOCK_BYREF_LAYOUT_EXTENDED
  const char *layout;
};


// Extended layout encoding.

// Values for Block_descriptor_3->layout with BLOCK_HAS_EXTENDED_LAYOUT
// and for Block_byref_3->layout with BLOCK_BYREF_LAYOUT_EXTENDED

// If the layout field is less than 0x1000, then it is a compact encoding
// of the form 0xXYZ: X strong pointers, then Y byref pointers,
// then Z weak pointers.

// If the layout field is 0x1000 or greater, it points to a
// string of layout bytes. Each byte is of the form 0xPN.
// Operator P is from the list below. Value N is a parameter for the operator.
// Byte 0x00 terminates the layout; remaining block data is non-pointer bytes.

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

/**
NOTE:
Here is code from the clang project, which defined at CGObjecCMac.cpp.
Comment in libclouse project seem inaccurate.
  
/// opcode for captured block variables layout 'instructions'.
/// In the following descriptions, 'I' is the value of the immediate field.
/// (field following the opcode).
///
enum BLOCK_LAYOUT_OPCODE {
 /// An operator which affects how the following layout should be
 /// interpreted.
 ///   I == 0: Halt interpretation and treat everything else as
 ///           a non-pointer.  Note that this instruction is equal
 ///           to '\0'.
 ///   I != 0: Currently unused.
 BLOCK_LAYOUT_OPERATOR = 0,

 /// The next I+1 bytes do not contain a value of object pointer type.
 /// Note that this can leave the stream unaligned, meaning that
 /// subsequent word-size instructions do not begin at a multiple of
 /// the pointer size.
 BLOCK_LAYOUT_NON_OBJECT_BYTES  = 1,

 /// The next I+1 words do not contain a value of object pointer type.
 /// This is simply an optimized version of BLOCK_LAYOUT_BYTES for
 /// when the required skip quantity is a multiple of the pointer size.
 BLOCK_LAYOUT_NON_OBJECT_WORDS = 2,

 /// The next I+1 words are __strong pointers to Objective-C
 /// objects or blocks.
 BLOCK_LAYOUT_STRONG  = 3,

 /// The next I+1 words are pointers to __block variables.
 BLOCK_LAYOUT_BYREF = 4,

 /// The next I+1 words are __weak pointers to Objective-C
 /// objects or blocks.
 BLOCK_LAYOUT_WEAK = 5,

 /// The next I+1 words are __unsafe_unretained pointers to
 /// Objective-C objects or blocks.
 BLOCK_LAYOUT_UNRETAINED = 6

 /// The next I+1 words are block or object pointers with some
 /// as-yet-unspecified ownership semantics.  If we add more
 /// flavors of ownership semantics, values will be taken from
 /// this range.
 ///
 /// This is included so that older tools can at least continue
 /// processing the layout past such things.
 //BLOCK_LAYOUT_OWNERSHIP_UNKNOWN = 7..10,

 /// All other opcodes are reserved.  Halt interpretation and
 /// treat everything else as opaque.
};
*/

// Runtime support functions used by compiler when generating copy/dispose helpers

// Values for _Block_object_assign() and _Block_object_dispose() parameters
enum {
  // see function implementation for a more complete description of these fields and combinations
  BLOCK_FIELD_IS_OBJECT   =  3,  // id, NSObject, __attribute__((NSObject)), block, ...
  BLOCK_FIELD_IS_BLOCK    =  7,  // a block variable
  BLOCK_FIELD_IS_BYREF    =  8,  // the on stack structure holding the __block variable
  BLOCK_FIELD_IS_WEAK     = 16,  // declared __weak, only used in byref copy helpers
  BLOCK_BYREF_CALLER      = 128, // called from __block (byref) copy/dispose support routines.
};

enum {
  BLOCK_ALL_COPY_DISPOSE_FLAGS =
    BLOCK_FIELD_IS_OBJECT | BLOCK_FIELD_IS_BLOCK | BLOCK_FIELD_IS_BYREF |
    BLOCK_FIELD_IS_WEAK | BLOCK_BYREF_CALLER
};

#endif /* _BLOCK_PRIVATE_H_ */
