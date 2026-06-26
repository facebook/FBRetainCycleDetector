/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBObjectiveCGraphElement+Internal.h"

#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <malloc/malloc.h>

#import <FBReport/FBReport.h>

#import "FBAssociationManager.h"
#import "FBClassStrongLayout.h"
#import "FBObjectGraphConfiguration.h"
#import "FBRetainCycleUtils.h"
#import "FBRetainCycleDetector.h"
#import "FBClassSwiftHelpers.h"

extern "C" char *swift_demangle(
    const char *mangledName,
    size_t mangledNameLength,
    char *outputBuffer,
    size_t *outputBufferSize,
    uint32_t flags);

// Pure Swift objects are refcounted by the Swift runtime, not ObjC ARC. To pin
// one alive we call swift_retain/swift_release directly — the same mechanism
// FBSwiftStrongRef uses to keep RCD candidates alive. Resolved lazily via dlsym
// so this library carries no link-time dependency on the Swift runtime; if the
// process has no Swift runtime there are no Swift candidates to retain anyway.
typedef void (*FBRCDSwiftRefFunction)(void *);

static FBRCDSwiftRefFunction _fbRCDSwiftRetain = NULL;
static FBRCDSwiftRefFunction _fbRCDSwiftRelease = NULL;

static void FBRCDEnsureSwiftRuntime(void)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _fbRCDSwiftRetain = (FBRCDSwiftRefFunction)dlsym(RTLD_DEFAULT, "swift_retain");
    _fbRCDSwiftRelease = (FBRCDSwiftRefFunction)dlsym(RTLD_DEFAULT, "swift_release");
  });
}

@protocol FBRetainCycleDetectorCustomClassDescribable

- (NSString *)customClassDescription;

@end

@implementation FBObjectiveCGraphElement
{
  void *_unsafeSwiftObject;
}

- (instancetype)initWithObject:(id)object
{
  return [self initWithObject:object
                configuration:[FBObjectGraphConfiguration new]];
}

- (instancetype)initWithObject:(id)object
                 configuration:(nonnull FBObjectGraphConfiguration *)configuration
{
  return [self initWithObject:object
                configuration:configuration
                     namePath:nil];
}

- (instancetype)initWithObject:(id)object
                 configuration:(nonnull FBObjectGraphConfiguration *)configuration
                      namePath:(NSArray<NSString *> *)namePath
{
  if (self = [super init]) {
#if _INTERNAL_RCD_ENABLED
    // For an object that is not created using malloc/realloc, running RCD on it is pointless.
    // Hence adding a condition to check if object we are considering for RCD is malloced or not.
    malloc_zone_t *zone = malloc_zone_from_ptr((__bridge void *)object);
    if (zone) {
      // We are trying to mimic how ObjectiveC does storeWeak to not fall into
      // _objc_fatal path
      // https://github.com/bavarious/objc4/blob/3f282b8dbc0d1e501f97e4ed547a4a99cb3ac10b/runtime/objc-weak.mm#L369

      Class aCls = object_getClass(object);

      BOOL (*allowsWeakReference)(id, SEL) =
      (__typeof__(allowsWeakReference))class_getMethodImplementation(aCls, @selector(allowsWeakReference));

      if (allowsWeakReference && (IMP)allowsWeakReference != _objc_msgForward) {
        if (allowsWeakReference(object, @selector(allowsWeakReference))) {
          // This is still racey since allowsWeakReference could change it value by now.
          _object = object;
        }
      } else {
        _object = object;
      }
    }
#endif
    _namePath = namePath;
    _configuration = configuration;
  }

  return self;
}

- (instancetype)initWithUnsafeSwiftObject:(void *)objectPtr
                            configuration:(nonnull FBObjectGraphConfiguration *)configuration
                                 namePath:(NSArray<NSString *> *)namePath
{
  if (self = [super init]) {
#if _INTERNAL_RCD_ENABLED
    if (objectPtr && malloc_zone_from_ptr(objectPtr)) {
      // Take an owning Swift reference for this graph element's entire lifetime.
      // The caller (FBRCDManager) still holds an FBSwiftStrongRef on objectPtr
      // at this exact point, so the object is provably alive *now* — this is the
      // only safe moment to retain it. Holding the +1 here pins the object
      // across the whole detection pass (graph traversal AND leak reporting),
      // regardless of when ARC releases the caller's candidate array. Balanced
      // by swift_release in -dealloc. A retain taken later (e.g. inside
      // -allRetainedObjects) would be unsafe: by then the pointer may already be
      // dangling, so the retain itself would dereference freed memory.
      FBRCDEnsureSwiftRuntime();
      // Only adopt the pointer if we can both retain it now and release it in
      // -dealloc. Coupling the ivar store to a successful retain keeps the
      // retain/release pair balanced by construction: we never store a pointer
      // we didn't pin, so -dealloc can never over-release one we don't own.
      if (_fbRCDSwiftRetain && _fbRCDSwiftRelease) {
        _fbRCDSwiftRetain(objectPtr);
        _unsafeSwiftObject = objectPtr;
      }
    }
#endif
    _namePath = namePath;
    _configuration = configuration;
  }
  return self;
}

- (void)dealloc
{
#if _INTERNAL_RCD_ENABLED
  // Balance the swift_retain taken in -initWithUnsafeSwiftObject:. _object is a
  // weak property (ObjC path) and needs no release here; only the raw Swift
  // pointer carries an owning reference.
  //
  // Invariant: _unsafeSwiftObject is non-NULL IFF init successfully called
  // _fbRCDSwiftRetain on it. The init store is gated on (objectPtr &&
  // malloc_zone_from_ptr(objectPtr) && _fbRCDSwiftRetain && _fbRCDSwiftRelease)
  // and the assignment to _unsafeSwiftObject happens only after the retain
  // call — so a non-NULL ivar here implies a paired +1 to release, and a NULL
  // ivar means no retain was ever taken. Any future code path that writes
  // _unsafeSwiftObject without going through the retaining initializer MUST
  // null the ivar before -dealloc, or this will double-release.
  if (_unsafeSwiftObject && _fbRCDSwiftRelease) {
    _fbRCDSwiftRelease(_unsafeSwiftObject);
  }
#endif
}

- (void *)objectPtr
{
  if (_unsafeSwiftObject) {
    return _unsafeSwiftObject;
  }
  return (__bridge void *)_object;
}

- (NSSet *)allRetainedObjects
{
  void *ptr = [self objectPtr];
  if (!ptr) {
    return nil;
  }
  NSArray *retainedObjectsNotWrapped = [FBAssociationManager associationsForObject:(__bridge id)ptr];
  NSMutableSet *retainedObjects = [NSMutableSet new];

  for (id obj in retainedObjectsNotWrapped) {
    FBObjectiveCGraphElement *element = FBWrapObjectGraphElementWithContext(self,
                                                                            obj,
                                                                            _configuration,
                                                                            @[@"__associated_object"]);
    if (element) {
      [retainedObjects addObject:element];
    }
  }

  return retainedObjects;
}

- (BOOL)isEqual:(id)object
{
  if ([object isKindOfClass:[FBObjectiveCGraphElement class]]) {
    FBObjectiveCGraphElement *objcObject = object;
    return [objcObject objectPtr] == [self objectPtr];
  }
  return NO;
}

- (NSUInteger)hash
{
  return (size_t)[self objectPtr];
}

- (NSString *)description
{
  if (_namePath) {
    NSString *namePathStringified = [_namePath componentsJoinedByString:@" -> "];
    return [NSString stringWithFormat:@"-> %@ -> %@ ", namePathStringified, [self classNameOrNull]];
  }
  return [NSString stringWithFormat:@"-> %@ ", [self classNameOrNull]];
}

- (size_t)objectAddress
{
  return (size_t)[self objectPtr];
}

- (NSString *)classNameOrNull
{
  NSString *className;

  if (_unsafeSwiftObject) {
    Class cls = [self objectClass];
    if (cls) {
      const char *name = class_getName(cls);
      className = name ? [NSString stringWithUTF8String:name] : nil;
    }
  } else if (_object && ![_object isProxy] && [_object respondsToSelector:@selector(customClassDescription)]) {
    className = [_object customClassDescription];
  } else {
    className = NSStringFromClass(FBCastNonnullOrReportWarning([self objectClass]));
  }

  if (!className) {
    className = @"(null)";
  }

  // Demangle Swift class names (e.g. _TtC... → Module.ClassName)
  const char *cStr = [className UTF8String];
  if (cStr) {
    char *demangled = swift_demangle(cStr, strlen(cStr), nullptr, nullptr, 0);
    if (demangled) {
      className = [NSString stringWithUTF8String:demangled];
      free(demangled);

      // Strip private-type discriminators: "Module.(Foo in _HEX)" → "Module.Foo"
      NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"\\(([\\w.]+) in _[0-9A-Fa-f]+\\)"
                                                 options:0
                                                   error:nil];
      className = [regex stringByReplacingMatchesInString:className
                                                 options:0
                                                   range:NSMakeRange(0, className.length)
                                            withTemplate:@"$1"];
    }
  }

  return className;
}

- (Class)objectClass
{
  void *ptr = [self objectPtr];
  if (ptr) {
    return object_getClass((__bridge id)ptr);
  }
  return nil;
}

- (bool)isSwift
{
    Class cls = self.objectClass;
    return cls != nil && FBIsSwiftObjectOrClass(cls);
}

@end
