// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Avalon",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "AvalonCore", targets: ["AvalonCore"]),
    ],
    targets: [
        .target(name: "AvalonPixel"),
        .target(name: "AvalonJIT"),
        .target(name: "AvalonAudio"),
        .target(name: "AvalonChip8"),
        // The libretro API header is MIT and scoped to itself; hosting cores through it takes on
        // no copyleft from RetroArch, which is GPL-3.0.
        .target(name: "AvalonLibretro"),
        // A libretro core that exists only to test the frontend against the real ABI.
        .target(name: "AvalonLibretroTestCore", dependencies: ["AvalonLibretro"]),
        // Genesis Plus GX's own source, vendored (unmodified) at Libretro/genesis-plus-gx by the
        // repository's merge workflow. This target compiles it namespaced, per AvalonLibretro.h's
        // reason for existing: static linking on iOS, one core's symbols at a time.
        .target(
            name: "AvalonLibretroGenesisPlusGX",
            // Deliberately NOT a dependency on AvalonLibretro. That would give this target
            // Clang MODULES (-fmodules) for libretro.h, and Clang caches a module's precompiled
            // header with the macro environment frozen at module-build time -- before
            // genesisplusgx_namespace.h's #defines ever run. The renamed CALL sites and the
            // renamed DEFINITION still textually substitute, but the modular DECLARATION does
            // not, so the compiler sees an undeclared function and then a conflicting redefinition.
            // A plain header search path avoids the module path entirely and keeps this a
            // straightforward textual #include, which is what macro-based renaming requires.
            path: "Sources/AvalonLibretroGenesisPlusGXSource",
            sources: [
                "core", "core/z80", "core/m68k", "core/ntsc",
                "core/sound", "core/sound/minimp3", "core/input_hw", "core/cart_hw",
                "core/cart_hw/svp", "core/cd_hw",
                "libretro/libretro.c",
                // The subset of libretro-common (MIT-style) Genesis Plus GX's own
                // Makefile.common lists: file I/O, string/compat helpers, the VFS shim.
                "libretro-common/streams", "libretro-common/compat",
                "libretro-common/encodings", "libretro-common/file",
                "libretro-common/lists", "libretro-common/memmap", "libretro-common/string",
                "libretro-common/vfs",
            ],
            cSettings: [
                .headerSearchPath("libretro"),
                .headerSearchPath("libretro-common/include"),
                .headerSearchPath("../AvalonLibretro/include"),
                .headerSearchPath("core"),
                .headerSearchPath("core/z80"),
                .headerSearchPath("core/m68k"),
                .headerSearchPath("core/ntsc"),
                .headerSearchPath("core/sound"),
                .headerSearchPath("core/sound/minimp3"),
                .headerSearchPath("core/input_hw"),
                .headerSearchPath("core/cart_hw"),
                .headerSearchPath("core/cd_hw"),
                .headerSearchPath("core/cart_hw/svp"),
                .define("__LIBRETRO__"),
                .define("FRONTEND_SUPPORTS_RGB565", to: "1"),
                .define("USE_16BPP_RENDERING"),
                // Upstream's own Makefile.libretro sets this explicitly (LIBRETRO_CFLAGS +=
                // -DINLINE="static inline") rather than trusting retro_inline.h's #ifndef
                // fallback, which resolves to a bare C99 `inline` with no `static` the moment
                // ANY file's include chain reaches libretro-common's retro_inline.h before
                // core/macros.h's own INLINE definition -- a bare `inline` function provides no
                // out-of-line definition unless something else supplies `extern` linkage, so the
                // function silently has no linkable body. That is the actual root cause of every
                // "undefined symbol" this target has hit: CALC_FCSLOT, fd_9e, word_ram_switch,
                // and dozens of others were never an optimization-level issue at all.
                .define("INLINE", to: "static inline"),
                .define("HAVE_CHD", to: "0"),
                .define("MAX_ROM_SIZE", to: "10485760"),
                // A per-file -O2 override was not sufficient on its own -- z80.c's opcode
                // table (built the same way ym2413.c's CALC_FCSLOT was, via
                // `OP(prefix,opcode) -> static inline prefix##_##opcode`) still lost individual
                // entries to the same class of failure. A full `-c release` package build is
                // the one configuration verified completely clean; see
                // docs/ENGINEERING-MAP.md for the investigation. `swift test -c release` is
                // required for this target -- plain `swift test` will fail to link.
                .unsafeFlags(["-include", "genesisplusgx_namespace.h"]),
            ],
            linkerSettings: [.linkedLibrary("z")]
        ),
        // Bridges the namespaced gpgx_retro_* symbols to a vtable. Safe to depend on
        // AvalonLibretro normally -- see AvalonGenesisPlusGXGlue.h for why this file, unlike
        // AvalonLibretroGenesisPlusGX itself, doesn't have to avoid Clang modules.
        .target(
            name: "AvalonGenesisPlusGXGlue",
            dependencies: ["AvalonLibretro", "AvalonLibretroGenesisPlusGX"]
        ),
        // Nestopia's own source (C++), vendored unmodified at Libretro/nestopia. GPL-2.0-or-later,
        // verified against its own COPYING text ("either of that version or of any later
        // version"), not GitHub's ambiguous "GPL-2.0" tag. Same reason as Genesis Plus GX for
        // avoiding a dependency on AvalonLibretro here (Clang modules would freeze libretro.h's
        // declarations before nestopia_namespace.h's #defines run).
        .target(
            name: "AvalonLibretroNestopia",
            path: "Sources/AvalonLibretroNestopiaSource",
            exclude: [
                // Both meant to be #included directly, not compiled as their own translation
                // units; SwiftPM's directory-based source discovery tried to anyway and failed
                // writing a dependency file for each.
                "source/nes_ntsc/nes_ntsc.inl",
                "source/core/NstSoundRenderer.inl",
            ],
            sources: [
                "source", "libretro/libretro.cpp",
                "libretro-common/compat", "libretro-common/encodings", "libretro-common/file",
                "libretro-common/streams", "libretro-common/time", "libretro-common/vfs",
            ],
            cSettings: [
                .headerSearchPath("libretro"),
                .headerSearchPath("libretro-common/include"),
                .headerSearchPath("../AvalonLibretro/include"),
                .headerSearchPath("."),
                .define("__LIBRETRO__"),
                .unsafeFlags(["-include", "nestopia_namespace.h"]),
            ],
            cxxSettings: [
                .headerSearchPath("libretro"),
                .headerSearchPath("libretro-common/include"),
                .headerSearchPath("../AvalonLibretro/include"),
                .headerSearchPath("."),
                .define("__LIBRETRO__"),
                // Upstream's own initializer lists narrow int/double literals into
                // unsigned/float fields (e.g. libretro.cpp's retro_system_av_info construction).
                // Their own build doesn't treat it as fatal; this target's vendored source stays
                // byte-identical to upstream, so the flag is suppressed here instead of editing it.
                .unsafeFlags(["-include", "nestopia_namespace.h", "-Wno-c++11-narrowing"]),
            ]
        ),
        // Bridges the namespaced nestopia_retro_* symbols to a vtable, mirroring
        // AvalonGenesisPlusGXGlue.
        .target(
            name: "AvalonNestopiaGlue",
            dependencies: ["AvalonLibretro", "AvalonLibretroNestopia"]
        ),
        // mGBA's own source (C), vendored unmodified at Libretro/mgba. MPL-2.0. Its real build is
        // full CMake, with no standalone libretro Makefile the way Genesis Plus GX and Nestopia
        // have; two of its generated files (flags.h, version.c) are hand-resolved here instead --
        // see include/mgba/flags.h and src/core/version.c for exactly what was chosen and why.
        .target(
            name: "AvalonLibretroMGBA",
            path: "Sources/AvalonLibretroMGBASource",
            sources: [
                "src/arm", "src/core", "src/gb", "src/gba", "src/sm83", "src/util",
                "src/util/vfs/vfs-dirent.c", "src/util/vfs/vfs-file.c", "src/util/vfs/vfs-mem.c",
                "src/util/image.c",
                "src/third-party/inih/ini.c",
                "src/platform/libretro/libretro.c",
                "src/platform/libretro/libretro-audio.c",
                "src/platform/libretro/libretro-vfs.c",
            ],
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src"),
                .headerSearchPath("src/third-party"),
                .headerSearchPath("src/platform/libretro"),
                .headerSearchPath("../AvalonLibretro/include"),
                .define("__LIBRETRO__"),
                .unsafeFlags(["-include", "mgba_namespace.h", "-I", "Sources/AvalonLibretroMGBASource/ns_include"]),
            ],
            linkerSettings: [.linkedLibrary("z")]
        ),
        // Bridges the namespaced mgba_retro_* symbols to a vtable, mirroring
        // AvalonGenesisPlusGXGlue / AvalonNestopiaGlue.
        .target(
            name: "AvalonMGBAGlue",
            dependencies: ["AvalonLibretro", "AvalonLibretroMGBA"]
        ),
        .target(
            name: "AvalonCore",
            dependencies: ["AvalonPixel", "AvalonJIT", "AvalonAudio", "AvalonChip8", "AvalonLibretro",
                           "AvalonGenesisPlusGXGlue", "AvalonNestopiaGlue", "AvalonMGBAGlue"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "avalon-verify", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-run", dependencies: ["AvalonCore", "AvalonAudio"]),
        .executableTarget(name: "avalon-notice", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-bench", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-controls", dependencies: ["AvalonCore"]),
        // Proves Genesis Plus GX actually runs, not just compiles.
        .executableTarget(
            name: "avalon-genesisplusgx-smoketest",
            dependencies: ["AvalonCore"]
        ),
        .testTarget(
            name: "AvalonCoreTests",
            dependencies: ["AvalonCore", "AvalonLibretroTestCore"]
        ),
    ],
    // Nestopia's core is C++; this sets the standard package-wide rather than per-target, since a
    // per-target unsafeFlag in cxxSettings leaked "-std=c++14" into the SAME target's .c files
    // too (a mixed C/C++ target shares one flag set across both file kinds) and clang rejects a
    // C++ standard flag on a C compile outright.
    cxxLanguageStandard: .cxx14
)
