/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBClassSwiftHelpers.h"
#import <objc/runtime.h>

// The Objective-C runtime does not expose whether a class is a Swift class, so
// the structs below mirror just enough of its private `objc_class` layout to
// reach the flag word. Only `bits` is ever read; every other field exists to
// place it at the right offset, which the static_asserts below verify.
//
// The two flag values are part of the stable Swift ABI and are specified in
// https://github.com/swiftlang/swift/blob/main/docs/ObjCInterop.md
// The layout mirrored here is the runtime's; its authoritative definition lives
// in Apple's objc4 `objc-runtime-new.h`.

// class is a Swift class from the pre-stable Swift ABI
#define FAST_IS_SWIFT_LEGACY (1UL << 0)
// class is a Swift class from the stable Swift ABI
#define FAST_IS_SWIFT_STABLE (1UL << 1)

// Width of the runtime's method cache mask.
#if __LP64__
typedef uint32_t mask_t;
#else
typedef uint16_t mask_t;
#endif

// Size-only stand-in for the runtime's method cache. The union mirrors the
// runtime's own: the second word is either the mask/flags triple or a pointer
// to a preoptimized cache, depending on flags we never inspect.
struct fb_cache_t {
  uintptr_t _bucketsAndMaybeMask;
  union {
    struct {
      mask_t _maybeMask;
#if __LP64__
      uint16_t _flags;
#endif
      uint16_t _occupied;
    };
    void *_originalPreoptCache;
  };
};

struct fb_class_data_bits_t {
  uintptr_t bits;

  bool isAnySwift() const {
    return (bits & (FAST_IS_SWIFT_STABLE | FAST_IS_SWIFT_LEGACY)) != 0;
  }
};

struct fb_objc_class : objc_object {
  // Class ISA is inherited from objc_object.
  Class superclass;
  fb_cache_t cache;
  fb_class_data_bits_t bits;
};

static_assert(
    sizeof(fb_cache_t) == 2 * sizeof(uintptr_t),
    "fb_cache_t must match the runtime's cache_t size, otherwise bits is read from the wrong offset");
static_assert(
    sizeof(fb_objc_class) == 5 * sizeof(uintptr_t),
    "fb_objc_class must match the runtime's objc_class layout");

extern "C" BOOL FBIsSwiftObjectOrClass(id anything) {
  if (anything == nil) {
    return NO;
  }
  Class cls = anything;
  if (!object_isClass(cls)) {
    cls = object_getClass(cls);
  }

  struct fb_objc_class *objc_cls = (__bridge fb_objc_class *)cls;
  return objc_cls->bits.isAnySwift();
}
