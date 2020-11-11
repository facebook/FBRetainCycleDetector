/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBBlockStrongLayout2.h"
#import "Block_private.h"
#import "FBBlockStrongLayout.h"
#import <list>

#if __has_feature(objc_arc)
#error This file must be compiled with MRR. Use -fno-objc-arc flag.
#endif

struct RefrenceRange {
  size_t location;
  size_t length;
  
  RefrenceRange(size_t location, size_t length)
  : location(location), length(length) {}
};

#define StrongReferenceObject (0UL << (sizeof(size_t) * 8 - 1))
#define StrongReferenceByref  (1UL << (sizeof(size_t) * 8 - 1))
#define StrongReferenceMask   (1UL << (sizeof(size_t) * 8 - 1))

using std::list;

static inline struct Block_descriptor_3 * _Block_descriptor_3(struct Block_layout *aBlock) {
    if (!(aBlock->flags & BLOCK_HAS_SIGNATURE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct Block_descriptor_1);
    if (aBlock->flags & BLOCK_HAS_COPY_DISPOSE) {
        desc += sizeof(struct Block_descriptor_2);
    }
    return (struct Block_descriptor_3 *)desc;
}

static inline BOOL _IsBlockByrefStrong(struct Block_byref *aByref) {
  return (aByref->flags & BLOCK_BYREF_LAYOUT_STRONG) != 0
      && (aByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE) != 0;
}

static inline const void *_Nullable _GetBlockByrefStrongContent(struct Block_byref *aByref) {
  if ((aByref->flags & BLOCK_BYREF_LAYOUT_STRONG) == 0
      || (aByref->flags & BLOCK_BYREF_HAS_COPY_DISPOSE) == 0) {
    return NULL;
  }
  aByref = aByref->forwarding;
  assert((aByref->size & (sizeof(void *) - 1)) == 0);
  const void **slots = (const void **)aByref;
  return slots[(aByref->size / sizeof(void *)) - 1];
}

static void _GetBlockStrongLayout(struct Block_layout *blockLayout, list<RefrenceRange> &indices) {
  // Block doesn't have a dispose function, so it does not retain objects.
  if (!(blockLayout->flags & BLOCK_HAS_COPY_DISPOSE)) {
    return;
  }
  // Block doesn't have extended layout info that we depend on.
  if (!(blockLayout->flags & BLOCK_HAS_EXTENDED_LAYOUT)) {
    return;
  }
  struct Block_descriptor_3 *descriptor = _Block_descriptor_3(blockLayout);
  assert(descriptor != NULL);
  const char *layout = descriptor->layout;
  if ((size_t)layout < 0x1000) {
    size_t X = ((size_t)layout & 0xf00) >> 8;
    size_t Y = ((size_t)layout & 0x0f0) >> 4;
    if (X != 0) {
      indices.push_back(RefrenceRange((0UL | StrongReferenceObject), X));
    }
    if (Y != 0) {
      void **slots = (void **)(blockLayout + 1);
      for (int i = 0; i < Y; ++i) {
        if (_IsBlockByrefStrong((struct Block_byref *)slots[X + i])) {
          indices.push_back(RefrenceRange((X + i) | StrongReferenceByref, 1));
        }
      }
    }
  } else {
    size_t bytes = 0;
    for(uint8_t item = *layout; item != 0; item = *(++layout)) {
      const uint8_t P = item >> 4;
      // According apple's comment:
      //  "Value N is a parameter for the operator."
      //  "N words strong pointers"
      // However there is actually N + 1 pointer !!!
      const uint8_t N = (item & 0x0f) + 1;
      if (P == BLOCK_LAYOUT_STRONG) {
        indices.push_back(RefrenceRange((bytes / sizeof(void *)) | StrongReferenceObject, N));
      } else if (P == BLOCK_LAYOUT_BYREF) {
        const size_t _b = bytes / sizeof(void *);
        const void **slots = (const void **)(blockLayout + 1);
        for (int i = 0; i < N; ++i) {
          if (_IsBlockByrefStrong((struct Block_byref *)slots[_b + i])) {
            indices.push_back(RefrenceRange((_b + i) | StrongReferenceByref, 1));
          }
        }
      } else if (P == BLOCK_LAYOUT_ESCAPE) {
        break;
      }
      if (P == BLOCK_LAYOUT_NON_OBJECT_BYTES) {
        bytes += N;
      } else {
        bytes += (N * sizeof(void *));
        assert((bytes & (sizeof(void *) - 1)) == 0); // check alignment.
      }
      assert(P < BLOCK_LAYOUT_UNUSED_B); // these operators are unspecified now.
    }
    assert(bytes <= sizeof(struct Block_layout) + blockLayout->descriptor->size);
  }
}

NSArray *_Nullable FBGetBlockStrongReferences(void *_Nonnull block) {
  if (!FBObjectIsBlock(block)) {
    return nil;
  }
  struct Block_layout *blockLayout = (struct Block_layout *)block;
  if (!(blockLayout->flags & BLOCK_HAS_EXTENDED_LAYOUT)) {
    return FBGetBlockStrongReferencesV2(block);
  }
  
  list<RefrenceRange> indices;
  _GetBlockStrongLayout(blockLayout, indices);
  
  if (indices.size() == 0) {
    return nil;
  }
  
  NSMutableArray *results = [NSMutableArray array];
  void **blockReference = (void **)(blockLayout + 1);

  for (RefrenceRange &range : indices) {
    NSUInteger location = range.location & ~StrongReferenceMask;
    if ((range.location & StrongReferenceMask) == StrongReferenceObject) {
      for (NSUInteger i = location; i < location + range.length; ++i) {
        void *reference = blockReference[i];
        if (reference) {
          [results addObject:(id)(reference)];
        }
      }
    } else {
      assert(range.length == 1);
      void *_byref = blockReference[location];
      if (_byref == NULL) {
        continue;
      }
      const void *reference = _GetBlockByrefStrongContent((struct Block_byref *)_byref);
      if (reference) {
        [results addObject:(id)(reference)];
      }
    }
  }
  return results;
}
