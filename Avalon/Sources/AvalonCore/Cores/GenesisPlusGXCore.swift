// Avalon — Genesis Plus GX, hosted through the libretro frontend.
//
// The core itself is licence-cleared (LGPL-2.1-or-later, verified against its own LICENSE.txt
// text rather than GitHub's ambiguous "GPL-2.0" tag — see docs/ENGINEERING-MAP.md §5b) and
// vendored unmodified at `Libretro/genesis-plus-gx`. Getting it to actually LINK took finding a
// real bug in the build: its own `libretro/libretro-common/retro_inline.h` resolves `INLINE` to a
// bare C99 `inline` — which provides no callable out-of-line definition on its own — the moment
// any file's include chain reaches it before `core/macros.h`'s `static __inline__` does. Upstream's
// own Makefile.libretro works around exactly this with `-DINLINE="static inline"`
// (`AvalonLibretroGenesisPlusGX`'s `Package.swift` target does the same). Every "undefined
// symbol" this took to find — CALC_FCSLOT, fd_9e, word_ram_switch, dozens more — was this one
// cause, not an optimisation-level quirk.
//
// One further finding while wiring this up: `libretro/scrc32.h`, vendored alongside the core,
// declares the same `crc32` this needs but carries a non-commercial redistribution restriction —
// the same clause that already excludes Snes9x and Manic EMU's gated cores from this project. It
// is confirmed dead code (nothing here `#include`s it) and must stay that way; the system's own
// zlib supplies `crc32` instead, under the permissive zlib License.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AvalonGenesisPlusGXGlue

public enum GenesisPlusGXSpec: LibretroCoreSpec {
    public static func vtable() -> UnsafePointer<avalon_libretro_vtable> { avalon_genesisplusgx_vtable() }
    public static let coreID = "libretro.genesis-plus-gx"
    public static let displayName = "Genesis Plus GX"
    public static let version = "1.7.4"
    public static let system: SystemIdentifier = .genesis
    public static let nominalSize = PixelSize(width: 320, height: 224)
    public static let provenance: String? = "genesis-plus-gx"
}
