// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
/**
 * Copyright (c) 2016-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

/// A pure-Swift class (intentionally NOT an `NSObject` subclass) used to verify
/// the owning `swift_retain`/`swift_release` balance that `FBObjectiveCGraphElement`
/// takes on pure-Swift retain-cycle-detection candidates. Using a pure-Swift type
/// exercises the real Swift runtime refcounter — the path the production crash hit
/// — rather than the `objc_retain` fall-through an `NSObject` subclass would take.
private final class RCDDeinitProbe {
  static var deinitCount: Int = 0
  init() {}
  deinit { RCDDeinitProbe.deinitCount += 1 }
}

/// Obj-C-visible harness so `FBObjectiveCObjectTests` (Obj-C) can drive the
/// pure-Swift `RCDDeinitProbe`: vend a raw pointer, drop the single external
/// strong reference, and observe the deinit counter.
@objc(RCDDeinitProbeHarness)
final class RCDDeinitProbeHarness: NSObject {
  /// Number of times any `RCDDeinitProbe` has been deinitialized.
  @objc static var deinitCount: Int { RCDDeinitProbe.deinitCount }

  @objc static func resetDeinitCount() { RCDDeinitProbe.deinitCount = 0 }

  /// Returns a `+1`-owned raw pointer to a fresh pure-Swift probe, simulating
  /// the single `FBSwiftStrongRef` the RCD manager holds on a candidate. The
  /// caller must balance it with `releaseProbe(_:)`.
  @objc static func makeRetainedProbe() -> UnsafeMutableRawPointer {
    Unmanaged.passRetained(RCDDeinitProbe()).toOpaque()
  }

  /// Drops the simulated external reference taken by `makeRetainedProbe()`.
  @objc static func releaseProbe(_ pointer: UnsafeMutableRawPointer) {
    Unmanaged<RCDDeinitProbe>.fromOpaque(pointer).release()
  }
}
