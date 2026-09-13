// Avalon — Nestopia, hosted through the libretro frontend.
//
// GPL-2.0-or-later, verified against its own COPYING text ("either of that version or of any
// later version") rather than GitHub's ambiguous "GPL-2.0" tag. Vendored unmodified at
// Libretro/nestopia. A C++ core -- unlike Genesis Plus GX, its own `INLINE`-style macro trap
// never applied (C++ inline functions get proper ODR/COMDAT linkage from the language itself,
// not from a fragile `#ifndef` header convention), so getting this one to link needed only the
// same Clang-modules avoidance already established, plus suppressing a narrowing-conversion
// warning upstream's own build does not treat as fatal (`libretro.cpp`'s aggregate initializers
// narrow int/double literals into unsigned/float fields).
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AvalonNestopiaGlue

public enum NestopiaSpec: LibretroCoreSpec {
    public static func vtable() -> UnsafePointer<avalon_libretro_vtable> { avalon_nestopia_vtable() }
    public static let coreID = "libretro.nestopia"
    public static let displayName = "Nestopia"
    public static let version = "1.52 WIP"
    public static let system: SystemIdentifier = .nes
    public static let nominalSize = PixelSize(width: 256, height: 224)
    public static let provenance: String? = "nestopia"
}
