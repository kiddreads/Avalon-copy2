// Avalon — mGBA, hosted through the libretro frontend.
//
// MPL-2.0. Vendored unmodified at Libretro/mgba. Its real build is full CMake, with no
// standalone libretro Makefile the way Genesis Plus GX and Nestopia have; two of its
// configure_file-generated files (flags.h, version.c) are hand-resolved instead of generated --
// see include/mgba/flags.h and src/core/version.c for exactly what was chosen and why. One
// genuine third-party dependency, inih (a tiny BSD-licensed INI parser mGBA's own config.c
// needs), is vendored properly rather than worked around, since config.c's Configuration API is
// used even when the INI-file-reading half of it never runs.
//
// One system covers three catalog entries: Game Boy, Game Boy Color and Game Boy Advance all
// route through this same core, exactly as mGBA itself hosts all three.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AvalonMGBAGlue

public enum MGBASpec: LibretroCoreSpec {
    public static func vtable() -> UnsafePointer<avalon_libretro_vtable> { avalon_mgba_vtable() }
    public static let coreID = "libretro.mgba"
    public static let displayName = "mGBA"
    public static let version = "0.10"
    public static let system: SystemIdentifier = .gameBoyAdvance
    public static let nominalSize = PixelSize(width: 240, height: 160)
    public static let provenance: String? = "mgba"
}
