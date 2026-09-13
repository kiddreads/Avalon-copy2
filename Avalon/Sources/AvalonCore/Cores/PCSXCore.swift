// Avalon — pcsx_rearmed, hosted through the libretro frontend.
//
// GPL-2.0-or-later, verified against actual source-file headers ("either version 2 of the
// License, or (at your option) any later version"), not GitHub's spdx_id tag.
//
// Upstream's own Makefile.libretro forces DYNAREC=0 on platform=ios-arm64 -- the "no JIT on iOS"
// decision already made for us, same spirit as Citra's dynarmic being disabled on aarch64. Only
// the plain interpreter (psxinterpreter.c) runs; no AvalonJIT integration needed. Has a real HLE
// BIOS (psxbios.c) -- no copyrighted Sony BIOS file required to boot a game.
//
// `retro_get_system_info` reports `need_fullpath = false` implicitly by NOT setting it at all in
// this core's own retro_get_system_info (unlike bsnes) -- game data arrives however
// avalon_libretro_load provides it, which already populates both info.path and info.data/size.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AvalonPCSXGlue

public enum PCSXSpec: LibretroCoreSpec {
    public static func vtable() -> UnsafePointer<avalon_libretro_vtable> { avalon_pcsx_vtable() }
    public static let coreID = "libretro.pcsx_rearmed"
    public static let displayName = "PCSX ReARMed"
    public static let version = "r26"
    public static let system: SystemIdentifier = .playStation
    // retro_get_system_av_info's default (pre-game) geometry: 256x240.
    public static let nominalSize = PixelSize(width: 256, height: 240)
    public static let provenance: String? = "pcsx_rearmed"
}
