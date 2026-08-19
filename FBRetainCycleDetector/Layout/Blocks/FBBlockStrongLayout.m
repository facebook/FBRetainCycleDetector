/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if __has_feature(objc_arc)
#error This file must be compiled with MRR. Use -fno-objc-arc flag.
#endif

#import "FBBlockStrongLayout.h"

#import <mach/mach.h>
#import <malloc/malloc.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <stdatomic.h>

#import "FBBlockInterface.h"
#import "FBBlockStrongRelationDetector.h"

// Apple tagged-pointer bit: high bit on 64-bit arm64, low bit elsewhere.
// Tagged pointers encode their value in the pointer bits and never reference
// real memory, so object_getClass decodes them safely without a dereference.
// arm64_32 (watchOS) also defines __arm64__ but has 32-bit pointers and uses
// the low bit, so gate the high-bit form on a 64-bit pointer width.
#if defined(__arm64__) && defined(__LP64__)
#define _FBRCD_TAGGED_POINTER_MASK (1ULL << 63)
#elif defined(__x86_64__) || defined(__arm64__)
#define _FBRCD_TAGGED_POINTER_MASK (1ULL)
#else
#define _FBRCD_TAGGED_POINTER_MASK 0ULL
#endif

static atomic_uint_fast64_t sFilteredCaptureSlotCount = 0;

uint64_t FBRCDFilteredCaptureSlotCount(void) {
  return atomic_load_explicit(&sFilteredCaptureSlotCount, memory_order_relaxed);
}

// Bump the process-wide filtered-slot counter, with a sampled os_log every
// 1000th rejection so a real product use-after-free never goes fully blind.
static void _NoteFilteredCaptureSlot(void) {
  uint64_t total = atomic_fetch_add_explicit(&sFilteredCaptureSlotCount, 1, memory_order_relaxed) + 1;
  if ((total % 1000) == 0) {
    static os_log_t sLog;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sLog = os_log_create("com.facebook.FBRetainCycleDetector", "BlockStrongLayout");
    });
    os_log(sLog, "Filtered %{public}llu suspicious capture slots", (unsigned long long)total);
  }
}

// Probe `len` bytes at `ptr` via vm_read_overwrite. Kernel-mediated, so it
// cannot itself fault on an invalid address — unlike malloc_size or a direct
// dereference, which can crash on torn / freed memory.
static BOOL _IsReadableMemory(const void *ptr, size_t len) {
  if (!ptr || (uintptr_t)ptr < 0x1000) {
    return NO;
  }
  // Callers probe <= sizeof(scratch) bytes; clamp defensively. A larger request
  // would only confirm the first 64 bytes are readable, so keep call-site sizes
  // within this bound rather than relying on the clamp.
  uint8_t scratch[64];
  if (len > sizeof(scratch)) {
    len = sizeof(scratch);
  }
  vm_size_t bytesRead = 0;
  kern_return_t kr = vm_read_overwrite(
      mach_task_self(),
      (vm_address_t)ptr,
      (vm_size_t)len,
      (vm_address_t)scratch,
      &bytesRead);
  return kr == KERN_SUCCESS && bytesRead == len;
}

/**
 Validate that a raw pointer is safe to bridge to `id` and retain.

 Two distinct failure modes are guarded here:
  - Non-ObjC heap captures (e.g. Swift closure contexts). Bridging those to
    `id` and retaining crashes in objc_retain. Rejected via the malloc_size /
    ISA checks below.
  - Torn / freed capture slots. RCD scans blocks on a background thread while
    other threads may be tearing down captures, so a slot can momentarily hold
    a torn or freed pointer. malloc_size / object_getClass are NOT safe on such
    a pointer, so we first probe readability with vm_read_overwrite (which
    cannot fault) before touching it.

 Validation chain:
  1. Non-null and above the reserved low page.
  2. Tagged pointers are always valid (decoded without a dereference).
  3. 8-byte aligned (all heap objects are).
  4. Readable (torn / freed slots fail here).
  5. Non-heap pointers (e.g. global blocks in __DATA) are accepted — Swift
     capture boxes are always heap-allocated, so malloc_size == 0 is safe.
  6. For heap-allocated pointers, the ISA must be readable and resolve to a
     class in __DATA (malloc_size == 0), not heap-allocated Swift metadata.

 The readability probe checks READ access at probe time only. It cannot close
 the inherent TOCTOU window against the teardown race, does not stop
 objc_retain's isa write from faulting on a read-only page, and still accepts a
 readable-but-non-object pointer (malloc_size == 0). This narrows the crash to a
 rare tail rather than eliminating it — RCD is a best-effort diagnostic.
 */
static BOOL _FBIsRetainableObjCPointer(const void *ptr) {
  if (!ptr) {
    return NO;
  }

  // Small integer-like values are torn slots, not objects. Reject before the
  // tagged-pointer check so garbage like 0x1 is never decoded as a tag.
  if ((uintptr_t)ptr < 0x1000) {
    _NoteFilteredCaptureSlot();
    return NO;
  }

  if (((uintptr_t)ptr & _FBRCD_TAGGED_POINTER_MASK) != 0) {
    if (object_getClass((__bridge id)ptr) != Nil) {
      return YES;
    }
    // An unregistered tag slot is torn garbage, not a live tagged object.
    _NoteFilteredCaptureSlot();
    return NO;
  }

  // All heap objects are 8-byte aligned; a misaligned non-tagged pointer is a
  // torn / freed capture slot, not a live object.
  if ((uintptr_t)ptr & 0x7) {
    _NoteFilteredCaptureSlot();
    return NO;
  }

  // Probe readability before any malloc_size / isa dereference — malloc_size
  // on freed memory is not guaranteed safe.
  if (!_IsReadableMemory(ptr, sizeof(void *))) {
    _NoteFilteredCaptureSlot();
    return NO;
  }

  // Non-heap pointers (e.g. global blocks in __DATA) are valid ObjC objects
  // when they appear as strong captures in a block layout. Swift capture
  // box metadata — the thing we need to reject — is always heap-allocated.
  if (malloc_size(ptr) == 0) {
    return YES;
  }

  // Heap-allocated pointer: verify its ISA is readable and a real ObjC class
  // (lives in __DATA, malloc_size == 0) rather than heap-allocated Swift
  // metadata.
  Class cls = object_getClass((__bridge id)ptr);
  if (!cls) {
    _NoteFilteredCaptureSlot();
    return NO;
  }
  if (!_IsReadableMemory((__bridge const void *)cls, sizeof(void *))) {
    _NoteFilteredCaptureSlot();
    return NO;
  }
  if (malloc_size((void *)cls) > 0) {
    return NO;
  }

  return YES;
}

/**
 Extract strong references from a block by parsing the block descriptor's
 layout encoding. The layout field describes which captured variables are
 strong, weak, byref, etc.

 The block descriptor is a variable-length structure. Fields after
 `reserved` and `size` are conditionally present depending on flag bits
 in the block literal. We must compute the layout field's offset
 dynamically rather than using a fixed struct member access.

 See: http://clang.llvm.org/docs/Block-ABI-Apple.html
 */

/**
 Compute the address of the layout field in the block descriptor.
 The descriptor has a variable layout:
   [reserved] [size]                                        -- always
   [copy_helper] [dispose_helper]                           -- if BLOCK_HAS_COPY_DISPOSE
   [signature]                                              -- if BLOCK_HAS_SIGNATURE
   [layout]                                                 -- if BLOCK_HAS_EXTENDED_LAYOUT
 */
static const char *_GetBlockDescriptorLayout(struct BlockLiteral *blockLiteral) {
  uint8_t *desc = (uint8_t *)blockLiteral->descriptor;

  // Skip past reserved and size (always present).
  desc += sizeof(unsigned long int); // reserved
  desc += sizeof(unsigned long int); // size

  if (blockLiteral->flags & BLOCK_HAS_COPY_DISPOSE) {
    desc += sizeof(void *); // copy_helper
    desc += sizeof(void *); // dispose_helper
  }

  if (blockLiteral->flags & BLOCK_HAS_SIGNATURE) {
    desc += sizeof(void *); // signature
  }

  return *(const char **)desc;
}

// Extract the strong capture stored in a __block byref slot, guarding every
// dereference so a torn byref pointer cannot crash the background scan.
static void _AppendByrefStrongReference(void *rawByref, NSMutableArray *strongReferences) {
  if (!rawByref) {
    return;
  }
  // Probe the Block_byref header before reading ->flags: a torn byref pointer
  // (or malloc_size on it) would otherwise fault before any guard below runs.
  if (!_IsReadableMemory(rawByref, sizeof(struct Block_byref))) {
    _NoteFilteredCaptureSlot();
    return;
  }
  if (malloc_size(rawByref) == 0) {
    return;
  }
  struct Block_byref *blockByref = (struct Block_byref *)rawByref;
  BOOL isStrongLayout = (blockByref->flags & BLOCK_BYREF_LAYOUT_MASK) == BLOCK_BYREF_LAYOUT_STRONG;
  BOOL hasCopyDispose = blockByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE;
  if (!hasCopyDispose || !isStrongLayout) {
    return;
  }
  void *byrefDesc = (uint8_t *)blockByref + sizeof(*blockByref);
  // The captured object sits just past the header, outside the region probed
  // above — probe it separately before dereferencing.
  if (!_IsReadableMemory(byrefDesc, sizeof(void *))) {
    _NoteFilteredCaptureSlot();
    return;
  }
  void *rawPtr = *((void **)byrefDesc);
  if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
    [strongReferences addObject:(__bridge id)rawPtr];
  }
}

static NSArray *_GetStrongReferencesCompactLayout(struct BlockLiteral *blockLiteral, const char *layout) {
  NSMutableArray *strongReferences = [NSMutableArray array];

  int strongReferenceCount = ((uintptr_t)layout & 0xF00) >> 8;
  int byrefReferenceCount = ((uintptr_t)layout & 0x0F0) >> 4;

  uintptr_t *storagePointer = (uintptr_t *)((uintptr_t)blockLiteral + sizeof(*blockLiteral));
  if (strongReferenceCount > 0) {
    for (int i = 0; i < strongReferenceCount; i += 1, storagePointer += 1) {
      void *rawPtr = *((void **)storagePointer);
      if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
        [strongReferences addObject:(__bridge id)rawPtr];
      }
    }
  }

  if (byrefReferenceCount > 0) {
    for (int i = 0; i < byrefReferenceCount; i += 1, storagePointer += 1) {
      _AppendByrefStrongReference(*((void **)storagePointer), strongReferences);
    }
  }

  return strongReferences;
}

static NSArray *_GetStrongReferencesExtendedLayout(struct BlockLiteral *blockLiteral, const char *blockLayout)
{
  NSMutableArray *strongReferences = [NSMutableArray array];

  uintptr_t *storagePointer = (uintptr_t *)((uintptr_t)blockLiteral + sizeof(*blockLiteral));
  uintptr_t wordOffset = 0;

  for (int i = 0; blockLayout[i] != 0x00; i++) {
    int p = (blockLayout[i] & 0xF0) >> 4;
    int n = (blockLayout[i] & 0x0F) + 1;
    if (p == BLOCK_LAYOUT_STRONG) {
      for (int j = 0; j < n; j++) {
        void *ptr = ((uintptr_t *)storagePointer + wordOffset + j);
        void *rawPtr = *((void **)ptr);
        if (rawPtr && _FBIsRetainableObjCPointer(rawPtr)) {
          [strongReferences addObject:(__bridge id)rawPtr];
        }
      }
    } else if (p == BLOCK_LAYOUT_BYREF) {
      for (int j = 0; j < n; j++) {
        uintptr_t *ptr = ((uintptr_t *)storagePointer + wordOffset + j);
        _AppendByrefStrongReference(*((void **)ptr), strongReferences);
      }
    }
    wordOffset += n;
  }

  return strongReferences;
}

NSArray *FBGetBlockStrongReferences(void *block) {
  if (!FBObjectIsBlock(block)) {
    return nil;
  }

  NSMutableArray *results = [NSMutableArray new];

  struct BlockLiteral *blockLiteral = block;

  if (!(blockLiteral->flags & BLOCK_HAS_EXTENDED_LAYOUT) ||
      !(blockLiteral->flags & BLOCK_HAS_COPY_DISPOSE)) return results;

  // The layout field's position in the descriptor depends on which optional
  // fields are present. Compute it dynamically based on flag bits.
  const char *layout = _GetBlockDescriptorLayout(blockLiteral);
  if ((uintptr_t)layout < 0x1000) {
    return _GetStrongReferencesCompactLayout(blockLiteral, layout);
  } else {
    return _GetStrongReferencesExtendedLayout(blockLiteral, layout);
  }
}

static Class _BlockClass(void) {
  static dispatch_once_t onceToken;
  static Class blockClass;
  dispatch_once(&onceToken, ^{
    void (^testBlock)(void) = [^{} copy];
    blockClass = [testBlock class];
    while(class_getSuperclass(blockClass) && class_getSuperclass(blockClass) != [NSObject class]) {
      blockClass = class_getSuperclass(blockClass);
    }
    [testBlock release];
  });
  return blockClass;
}

BOOL FBObjectIsBlock(void *object) {
  Class blockClass = _BlockClass();

  Class candidate = object_getClass((__bridge id)object);
  return [candidate isSubclassOfClass:blockClass];
}
