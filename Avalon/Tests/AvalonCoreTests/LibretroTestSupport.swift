// Avalon — serializing every libretro-backed test suite against every other one.
//
// `avalon_libretro_open` enforces one active session process-wide (`g_active` in
// AvalonLibretro.c), matching libretro's own reality. `@Suite(.serialized)` only serializes tests
// *within* one suite; two different suites (LibretroCoreTests, GenesisPlusGXCoreTests) can still
// run concurrently with each other under swift-testing's default parallelism, and did the moment
// a second libretro-backed suite existed — surfacing as `invalidTransition(from: .stopped, to:
// .running)` when one suite's open raced another's. This lock is the actual fix: it serializes
// every test that touches the shared C global, regardless of which suite it lives in.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

enum LibretroTestLock {
    private static let lock = NSLock()

    static func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
