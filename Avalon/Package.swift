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
                .headerSearchPath("ns_include"),
                .headerSearchPath("../AvalonLibretro/include"),
                .define("__LIBRETRO__"),
                // headerSearchPath (above) is always relative to this target's own `path` and
                // resolves correctly regardless of build system; a raw `-I` with a
                // package-root-relative path here worked for `swift build` (invoked from the
                // package root) but not for Xcode's own build ("Build AvalonCore for the iOS
                // Simulator" in CI), which resolves unsafeFlags paths differently --
                // "'mgba_namespace.h' file not found" the first time this ran against the iOS SDK.
                .unsafeFlags(["-include", "mgba_namespace.h"]),
            ],
            linkerSettings: [.linkedLibrary("z")]
        ),
        // Bridges the namespaced mgba_retro_* symbols to a vtable, mirroring
        // AvalonGenesisPlusGXGlue / AvalonNestopiaGlue.
        .target(
            name: "AvalonMGBAGlue",
            dependencies: ["AvalonLibretro", "AvalonLibretroMGBA"]
        ),
        // bsnes's own source (C++17), vendored unmodified at Libretro/bsnes. GPL-3.0-only --
        // see License.swift's .gpl3Only case for why that's not a compatibility trap the way
        // GPL-2.0-only would be. Unlike the other three cores, bsnes's own target-libretro build
        // has no libretro-common dependency at all (its utility layer is nall, its own,
        // namespaced under C++ namespaces already) -- so bsnes_namespace.h only has to rename the
        // 24 RETRO_API entry points, not internal helper symbols too. Same reason as the other
        // three for avoiding a dependency on AvalonLibretro here (Clang modules would freeze
        // libretro.h's declarations before bsnes_namespace.h's #defines run).
        //
        // Real, upstream-authored SNES source in this target: `sfc/`, `processor/`,
        // `emulator/`, `filter/`, `heuristics/`. bsnes also builds a *second*, independent
        // GB/GBC core (`gb/Core`, a vendored SameBoy fork, MIT) unconditionally -- Super Game Boy
        // support routes a SNES-hosted SGB cartridge's inserted GB ROM through it
        // (`sfc/coprocessor/icd/icd.cpp` calls `platform->load(ID::GameBoy, ...)` and
        // `cartridge.slotGameBoy`), and `sfc/coprocessor/coprocessor.cpp`'s unity build
        // unconditionally references those symbols -- so it has to be linked in for any bsnes
        // build, not only ones that want to play GB ROMs directly. Avalon's own GB/GBC play still
        // goes through mGBA; this is bsnes's own SGB plumbing, unused by anything outside SGB
        // carts.
        //
        // Only listing the real translation units here, not whole directories: like Genesis Plus
        // GX/Nestopia/mGBA before it, bsnes's own build is a unity build where most .cpp files
        // (e.g. every sfc/coprocessor/*/*.cpp, filter/*.cpp, lzma/*.c) are meant to be #included
        // by exactly one top-level file, never compiled as their own translation unit --
        // SwiftPM's directory-based discovery doesn't know that distinction, so `sources:` names
        // only the ~20 real entry points bsnes's own GNUmakefiles compile, plus gb/Core's 15 real
        // per-file objects (debugger.c and sm83_disassembler.c excluded, matching upstream's own
        // Makefile -- DISABLE_DEBUGGER, below).
        .target(
            name: "AvalonLibretroBsnes",
            path: "Sources/AvalonLibretroBsnesSource",
            sources: [
                "libco/libco.c",
                "emulator/emulator.cpp",
                "filter/filter.cpp",
                "lzma/lzma.cpp",
                "sfc/interface/interface.cpp",
                "sfc/system/system.cpp",
                "sfc/controller/controller.cpp",
                "sfc/cartridge/cartridge.cpp",
                "sfc/memory/memory.cpp",
                "sfc/cpu/cpu.cpp",
                "sfc/smp/smp.cpp",
                "sfc/dsp/dsp.cpp",
                "sfc/ppu/ppu.cpp",
                "sfc/ppu-fast/ppu.cpp",
                "sfc/expansion/expansion.cpp",
                "sfc/coprocessor/coprocessor.cpp",
                "sfc/slot/slot.cpp",
                "processor/wdc65816/wdc65816.cpp",
                "processor/spc700/spc700.cpp",
                "processor/arm7tdmi/arm7tdmi.cpp",
                // program.cpp is NOT its own translation unit -- target-libretro/libretro.cpp
                // itself does `#include "program.cpp"` partway through (that's where the
                // input_state/video_cb/environ_cb statics program.cpp calls actually live).
                // Listing both here compiled program.cpp twice, once orphaned from those statics.
                "target-libretro/libretro.cpp",
                "gb/Core/apu.c",
                "gb/Core/camera.c",
                "gb/Core/display.c",
                "gb/Core/gb.c",
                "gb/Core/joypad.c",
                "gb/Core/mbc.c",
                "gb/Core/memory.c",
                "gb/Core/printer.c",
                "gb/Core/random.c",
                "gb/Core/rewind.c",
                "gb/Core/save_state.c",
                "gb/Core/sgb.c",
                "gb/Core/sm83_cpu.c",
                "gb/Core/symbol_hash.c",
                "gb/Core/timing.c",
            ],
            cSettings: [
                .headerSearchPath("."),
                .define("__LIBRETRO__"),
                .define("GB_INTERNAL"),
                .define("DISABLE_DEBUGGER"),
                .define("HAVE_POSIX_MEMALIGN"),
                .unsafeFlags(["-include", "bsnes_namespace.h"]),
            ],
            cxxSettings: [
                .headerSearchPath("."),
                .define("__LIBRETRO__"),
                .unsafeFlags(["-include", "bsnes_namespace.h"]),
            ]
        ),
        // Bridges the namespaced bsnes_retro_* symbols to a vtable, mirroring
        // AvalonGenesisPlusGXGlue / AvalonNestopiaGlue / AvalonMGBAGlue.
        .target(
            name: "AvalonBsnesGlue",
            dependencies: ["AvalonLibretro", "AvalonLibretroBsnes"]
        ),
        // pcsx_rearmed's own source (C), vendored unmodified at Libretro/pcsx_rearmed.
        // GPL-2.0-or-later, verified against actual source-file headers ("either version 2 of
        // the License, or (at your option) any later version"), not GitHub's spdx_id tag. The
        // real per-file OBJS list below was extracted by actually running
        // `make -f Makefile.libretro platform=ios-arm64 HAVE_CHD=0 -p -n` and reading the
        // resolved OBJS/CFLAGS variables out of make's own database -- not by hand-tracing
        // GNUmakefile conditionals the way bsnes's unity build required, since this build is a
        // real per-file one (each .o a distinct .c/.S, no unity #include chains).
        //
        // DRC_DISABLE (-DDRC_DISABLE): upstream's own Makefile.libretro forces DYNAREC=0 on
        // platform=ios-arm64 -- the "no JIT on iOS" decision already made for us, same spirit as
        // Citra's dynarmic being disabled on aarch64. Only the plain interpreter
        // (psxinterpreter.c) runs; no AvalonJIT integration needed.
        //
        // HAVE_CHD=0 (matching Genesis Plus GX's own precedent): skips vendoring libchdr's
        // compressed-disc-image support (LZMA/zstd/FLAC decoders) for this first cut -- .bin/.cue
        // and raw .exe (PS-EXE homebrew) still load. GPU_NEON selects the NEON-optimized software
        // rasterizer (gpu_neon), matching Avalon's software-framebuffer contract; nullsnd is the
        // audio *output* stub (irrelevant here -- plugins/dfsound/spu.c still computes real
        // samples, which reach Avalon through the standard retro_audio_sample_batch callback like
        // every other core, never through pcsx_rearmed's own OS-level audio driver).
        //
        // gte_arm64.S/gte_nf_arm64.S are hand-written AArch64 assembly (the GTE, PS1's fixed-point
        // 3D coprocessor) -- the first real assembly in this repository. Confirmed SwiftPM
        // compiles and links `.S` sources correctly in a plain library target before committing
        // to including them, rather than assuming.
        //
        // Deliberately NOT a dependency on AvalonLibretro, same reason as every other core here
        // (Clang modules would freeze libretro.h's declarations before pcsx_namespace.h's
        // #defines run). pcsx_rearmed vendors its own libretro-common snapshot, which -- like
        // Genesis Plus GX, Nestopia and mGBA before it -- collides with the other three cores'
        // own snapshots the moment all four share one binary; pcsx_namespace.h namespaces both
        // the 24 RETRO_API entry points (pcsx_retro_*) and pcsx_rearmed's own internal
        // libretro-common utility symbols (psx_lrc_*), generated from the actual compiled .c
        // files the same way as the other three. strlcat/strlcpy are deliberately excluded from
        // the rename list: compat_strl.c guards both out entirely on Darwin, relying on the
        // system libc's own versions -- the same reason Nestopia's namespace header excludes them.
        .target(
            name: "AvalonLibretroPCSX",
            path: "Sources/AvalonLibretroPCSXSource",
            sources: [
                "libpcsxcore/cdriso.c",
                "libpcsxcore/cdrom.c",
                "libpcsxcore/cdrom-async.c",
                "libpcsxcore/cheat.c",
                "libpcsxcore/database.c",
                "libpcsxcore/decode_xa.c",
                "libpcsxcore/mdec.c",
                "libpcsxcore/misc.c",
                "libpcsxcore/plugins.c",
                "libpcsxcore/ppf.c",
                "libpcsxcore/psxbios.c",
                "libpcsxcore/psxcommon.c",
                "libpcsxcore/psxcounters.c",
                "libpcsxcore/psxdma.c",
                "libpcsxcore/psxhw.c",
                "libpcsxcore/psxinterpreter.c",
                "libpcsxcore/psxmem.c",
                "libpcsxcore/psxevents.c",
                "libpcsxcore/r3000a.c",
                "libpcsxcore/sio.c",
                "libpcsxcore/spu.c",
                "libpcsxcore/gpu.c",
                "libpcsxcore/pad.c",
                "libpcsxcore/gte.c",
                "libpcsxcore/gte_nf.c",
                "libpcsxcore/gte_divider.c",
                "libpcsxcore/gte_arm64.S",
                "libpcsxcore/gte_nf_arm64.S",
                "libpcsxcore/new_dynarec/emu_if.c",
                "plugins/dfsound/dma.c",
                "plugins/dfsound/freeze.c",
                "plugins/dfsound/registers.c",
                "plugins/dfsound/spu.c",
                "plugins/dfsound/out.c",
                "plugins/dfsound/nullsnd.c",
                "plugins/gpulib/gpu.c",
                "plugins/gpulib/vout_pl.c",
                "plugins/gpulib/prim.c",
                "plugins/gpu_neon/psx_gpu_if.c",
                "plugins/gpu_neon/psx_gpu/psx_gpu_simd.c",
                "deps/miniz/miniz.c",
                "frontend/cspace.c",
                "deps/libretro-common/compat/compat_strl.c",
                "deps/libretro-common/file/file_path.c",
                "deps/libretro-common/file/file_path_io.c",
                "deps/libretro-common/string/stdstring.c",
                "deps/libretro-common/vfs/vfs_implementation.c",
                "deps/libretro-common/compat/compat_posix_string.c",
                "deps/libretro-common/compat/fopen_utf8.c",
                "deps/libretro-common/encodings/encoding_utf.c",
                "deps/libretro-common/file/retro_dirent.c",
                "deps/libretro-common/streams/file_stream.c",
                "deps/libretro-common/streams/file_stream_transforms.c",
                "deps/libretro-common/time/rtime.c",
                "frontend/libretro.c",
                "frontend/pcsxr-threads.c",
                "deps/libretro-common/features/features_cpu.c",
                // Renamed from upstream's frontend/main.c (same content): a file literally
                // named main.c made SwiftPM's executable-target auto-detection kick in even
                // inside a plain .target(), which broke this file's own quoted #include "menu.h"
                // resolution -- it picked up the SDK's ncurses menu.h instead of the local one,
                // "conflicting types for 'menu_init'". Not just a CLI entry point despite the
                // name: also defines emu_core_init/emu_save_state/set_cd_image/etc, which
                // frontend/libretro.c genuinely calls into.
                "frontend/psx_main.c",
                "frontend/plugin.c",
            ],
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include"),
                .headerSearchPath("deps/libretro-common/include"),
                .headerSearchPath("deps/miniz"),
                .headerSearchPath("../AvalonLibretro/include"),
                .define("IOS"),
                .define("GPU_NEON"),
                .define("NDEBUG"),
                .define("P_HAVE_MMAP", to: "1"),
                .define("P_HAVE_POSIX_MEMALIGN", to: "1"),
                .define("DISABLE_MEM_LUTS", to: "0"),
                .define("DRC_DISABLE"),
                .define("USE_MINIZ"),
                .define("USE_LIBRETRO_VFS"),
                .define("HAVE_LIBRETRO"),
                .define("NO_FRONTEND"),
                .define("__LIBRETRO__"),
                // Per-file CFLAGS override in the real Makefile (psx_gpu_if.o and
                // psx_gpu_simd.o both get -DSIMD_BUILD); SwiftPM has no per-file cSettings
                // scoping, so this applies target-wide -- harmless elsewhere, checked only by
                // psx_gpu_simd.c/.h.
                .define("SIMD_BUILD"),
                // Another per-file override missed on the first pass: without NEON_BUILD,
                // psx_gpu.c's own #ifndef NEON_BUILD block defines its *own* generic-C fallback
                // bodies for the same blend/shade/texture function names psx_gpu_simd.c
                // implements for real -- both ending up as real, non-static, same-named globals
                // once linked, hence "duplicate symbol '_blend_blocks_textured_add_fourth_on'".
                .define("NEON_BUILD"),
                .define("TEXTURE_CACHE_4BPP"),
                .define("TEXTURE_CACHE_8BPP"),
                // USE_ASYNC_GPU deliberately left undefined and gpu_async.c excluded from
                // sources: rather than the per-file CFLAGS override the real Makefile uses
                // (gpu_async.h's gpu_async_enabled() macro just becomes 0, so gpu.c calls
                // renderer_notify_screen_change() directly instead of the async path).
                // First-cut choice for build/runtime simplicity over overlapped CPU/GPU
                // threading -- confirmed necessary, not just simpler: with USE_ASYNC_GPU on and
                // gpu_async.c linked in, retro_run() SIGSEGV'd inside the GP1(0x08) display-mode
                // handler's gpu_async_notify_screen_change() call, every time, traced via a
                // temporary debug build (lldb's debugserver isn't permitted to attach in this
                // environment) that showed the crash landing right after that call and before
                // any of this core's own retro_run ever printed -- not something worth chasing
                // down for a first cut when the synchronous path avoids it entirely.
                .define("USE_ASYNC_SPU"),
                .define("USE_ASYNC_CDROM"),
                // SwiftPM always compiles C targets with -fmodules. With it on, merely
                // including <stdio.h>/<unistd.h>/etc. implicitly pulls in an umbrella SDK module
                // that also declares ncurses' menu_init() -- so frontend/menu.h's OWN, textually
                // #include-d, unrelated `void menu_init(void)` collides with the modularly
                // imported one ("conflicting types for 'menu_init'"), even though nothing here
                // ever textually includes ncurses. Confirmed via a minimal repro: identical flags
                // minus -fno-modules reproduce it standalone. -fno-modules avoids the implicit
                // umbrella import entirely, the same root cause this project already routes
                // around by never depending on AvalonLibretro from a vendored core's own target.
                .unsafeFlags(["-fno-modules", "-include", "pcsx_namespace.h"]),
            ],
            linkerSettings: [.linkedLibrary("z")]
        ),
        // Bridges the namespaced pcsx_retro_* symbols to a vtable, mirroring
        // AvalonGenesisPlusGXGlue / AvalonNestopiaGlue / AvalonMGBAGlue / AvalonBsnesGlue.
        .target(
            name: "AvalonPCSXGlue",
            dependencies: ["AvalonLibretro", "AvalonLibretroPCSX"]
        ),
        .target(
            name: "AvalonCore",
            dependencies: ["AvalonPixel", "AvalonJIT", "AvalonAudio", "AvalonChip8", "AvalonLibretro",
                           "AvalonGenesisPlusGXGlue", "AvalonNestopiaGlue", "AvalonMGBAGlue", "AvalonBsnesGlue",
                           "AvalonPCSXGlue"],
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
    // C++ standard flag on a C compile outright. bsnes's nall library requires C++17 (structured
    // bindings, if-constexpr, inline variables) -- the same mixed-target flag-sharing bug means a
    // per-target override isn't an option for it either, so this raises the package-wide floor to
    // C++17 rather than C++14. Nestopia's C++ builds and tests unchanged under C++17 (verified);
    // a newer standard being a superset of the one a codebase was written against is the normal
    // case, not the exception.
    cxxLanguageStandard: .cxx17
)
