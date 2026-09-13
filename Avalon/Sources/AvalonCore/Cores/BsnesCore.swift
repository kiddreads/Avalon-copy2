// Avalon — bsnes, hosted through the libretro frontend.
//
// GPL-3.0-only. Vendored unmodified at Libretro/bsnes. See License.swift's .gpl3Only case for
// why that's not a compatibility trap the way GPL-2.0-only would be -- bsnes is already at
// generation 3, the same generation Avalon's own AGPL-3.0-or-later occupies.
//
// Unlike Genesis Plus GX, Nestopia and mGBA, bsnes's own target-libretro build has no
// libretro-common dependency at all -- its utility layer is nall, its own, already namespaced
// under C++ namespaces (SuperFamicom::, Emulator::, nall::) -- so bsnes_namespace.h only has to
// rename the 24 RETRO_API entry points. bsnes also builds a second, independent GB/GBC core
// (a vendored SameBoy fork) unconditionally, since Super Game Boy support routes a SNES-hosted
// SGB cartridge's inserted GB ROM through it; Avalon's own GB/GBC play still goes through mGBA,
// this is bsnes's own SGB plumbing and unused by anything outside SGB carts.
//
// `retro_get_system_info` reports `need_fullpath = true` (bsnes reads the ROM file itself via
// its own nall::file, rather than accepting an in-memory buffer) -- already satisfied by
// `avalon_libretro_load` populating both `info.path` and `info.data`/`info.size` regardless of
// which a given core actually reads.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AvalonBsnesGlue

public enum BsnesSpec: LibretroCoreSpec {
    public static func vtable() -> UnsafePointer<avalon_libretro_vtable> { avalon_bsnes_vtable() }
    public static let coreID = "libretro.bsnes"
    public static let displayName = "bsnes"
    public static let version = "115"
    public static let system: SystemIdentifier = .snes
    // retro_get_system_av_info's base geometry, non-overscan: 512x448.
    public static let nominalSize = PixelSize(width: 512, height: 448)
    public static let provenance: String? = "bsnes"
}
