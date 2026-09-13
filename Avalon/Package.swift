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
        .target(
            name: "AvalonCore",
            dependencies: ["AvalonPixel", "AvalonJIT", "AvalonAudio", "AvalonChip8", "AvalonLibretro",
                           "AvalonGenesisPlusGXGlue"],
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
    ]
)
