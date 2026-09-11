# Avalon — Engineering Map

Living document. Synchronized with the actual codebase; every claim below is traceable to a file
in this repository. Sections marked **[verified]** were checked against source in this session.
Sections marked **[analysis]** are judgements derived from that source.

- Repository: `kiddreads/Avalon-copy2`
- Snapshot: `main` @ `6fa7b92`, 154,025 commits, 83,422 tracked files, ~1.90 GB
- Status of this document: Phase 1 (Discovery) — see `INTEGRATION-STATUS.md` for what is actually built.

---

## 1. Repository inventory [verified]

Ten source projects, no pre-existing Avalon code. (Grep for `Avalon` matches only `Avalonia`,
the C# UI toolkit vendored inside MeloNX/Ryujinx — unrelated.)

| Project | Emulates | Primary language | Tracked files | Size | License |
|---|---|---|---|---|---|
| `Delta` | NES/SNES/N64/GB/GBC/GBA/DS/GEN (multi) | Swift | 1,385 | 71.1 MB | AGPL-3.0 |
| `Fin` | GameCube / Wii | C++ / Swift | 30,299 | 783.2 MB | GPL-2.0-or-later |
| `Folium` | 3DS/NDS/NES/GBA/MD/ColecoVision (multi) | Swift + ObjC++ / C++ | 6,218 | 183.0 MB | GPL-3.0 |
| `Manic EMU` | 40+ systems via libretro (multi) | Swift | 8,981 | 62.2 MB | AGPL-3.0 |
| `MeloNX` | Nintendo Switch | C# (.NET) + Swift | 4,951 | 139.5 MB | GPL-3.0 |
| `PPSSPP` | PlayStation Portable | C++ | 2,567 | 107.1 MB | GPL-2.0-or-later |
| `Play!` | PlayStation 2 | C++ | 1,332 | 8.7 MB | **BSD (permissive)** |
| `dolphin-ios` | GameCube / Wii | C++ / ObjC | 7,381 | 99.2 MB | GPL-2.0-or-later |
| `iCube` | GameCube / Wii | C++ / ObjC | 7,427 | 99.9 MB | GPL-2.0-or-later |
| `iPSX2` | PlayStation 2 | C++ / Swift | 12,880 | 350.4 MB | GPL-3.0 |

`.github/workflows/merge-emulators.yml` is a leftover one-shot workflow from the repo assembly; it is
not part of Avalon.

### Three projects are the same emulator, and one of them is a straight copy [verified]

`dolphin-ios`, `iCube` and `Fin` are all Dolphin derivatives.

**`iCube` is not a fork. It is a stale, unbranded copy of DolphiniOS.** The evidence is unambiguous:

- The string `iCube` appears **0 times** in `iCube/iCube/Source`, which still contains **500
  `DolphiniOS` references** and ships `Source/iOS/App/DolphiniOS.xcodeproj`.
- Its `Readme.md` is byte-identical to DolphiniOS's.
- Its **only** file not present in `dolphin-ios` is an app icon PNG
  (`Source/iOS/App/DolphiniOS/Assets.xcassets/AppIcon.appiconset/diosblue.png`).
- `diff -rq` reports 1,007 differing files and 23,456 changed Core lines, but all 15 generation
  markers put iCube uniformly **older**, not different: `STATE_VERSION` 170 (`Core/State.cpp:102`)
  vs 175; `VideoCommon/RenderBase.cpp` + `g_renderer` instead of the current
  `VideoCommon/EFBInterface.cpp`; SDL2 with `static_assert(!SDL_VERSION_ATLEAST(3,0,0))`
  (`InputCommon/ControllerInterface/SDL/SDL.cpp:474`) vs SDL3.
- 12,930 of its 14,122 changed iOS lines are two localization `Core.strings` files. Only 1,732 are code.
- It lacks the iOS JIT acquisition code that `dolphin-ios` has (`Common/MemoryUtil_iOS*.cpp` absent).

**Recommendation: remove `iCube` (7,427 files, 99.9 MB).** It contributes nothing `dolphin-ios` does
not already have, in a newer form. Git history retains it, exactly as CEMU was removed earlier.

**`Fin` is a real but narrow divergence** from a near-current DolphiniOS: only 3,675 changed Core
lines, and identical to `dolphin-ios` on all 15 generation markers (`STATE_VERSION` 175 in both;
`VideoCommon/ShaderCache.cpp` and `Common/Config/Config.cpp` byte-identical). Its investment is
concentrated in four places, all of which are genuinely unique in this repository — see the
component map below.

### Not everything that looks like a core is one [verified]
Folium declares 11 cores but only 8 contain an emulator. `Folium/Mango`, `Folium/Lychee` and
`Folium/Durian` each contain exactly three files (`bridge.h`, `bridge.mm`, `<Name>.swift`) and no
`System/` directory — they are bridge stubs with nothing behind them.
Delta's cores are **not in this repository at all**: every one is a git submodule pointing at
`github.com/rileytestut/*` (`Delta/.gitmodules`). What is present is the Delta app shell.
Manic EMU's 41 `Cores/*.libretro.framework` bundles are prebuilt binaries, not source.

---

## 2. Duplication, measured [verified]

**38 third-party libraries are vendored in two or more projects.** The worst offenders:

| Library | Copies | Projects |
|---|---|---|
| SDL | 7 | Fin, Folium, MeloNX, PPSSPP, dolphin-ios, iCube, iPSX2 |
| MoltenVK | 6 | Fin, Folium, MeloNX, PPSSPP, dolphin-ios, iCube |
| FFmpeg | 6 | Fin, Folium, PPSSPP, dolphin-ios, iCube, iPSX2 |
| rapidjson | 6 | Fin, Folium, PPSSPP, dolphin-ios, iCube, iPSX2 |
| zlib, zstd, glslang, imgui, rcheevos, discord-rpc | 5 each | — |
| SPIRV-Cross, libchdr, cubeb, curl, fmt, lz4, hidapi, libusb, xxhash, pugixml, FatFs, bzip2 | 4 each | — |

This is the single largest source of bulk in the repository and the clearest consolidation target.

---

## 3. Licensing [verified, decisive]

| License | Projects | Consequence |
|---|---|---|
| BSD (permissive) | Play! | Usable anywhere, including in a proprietary or differently-licensed shell |
| GPL-2.0-**or-later** | Fin, dolphin-ios, iCube, PPSSPP | Upgradeable to v3 ⇒ combinable with GPLv3/AGPLv3 |
| GPL-3.0 | Folium, iPSX2, MeloNX | Combinable with AGPLv3 (GPLv3 §13) |
| AGPL-3.0 | Delta, Manic EMU | Strongest copyleft present |

**Consequence for architecture:** if Avalon links all of this into one binary, the combined work must be
**AGPL-3.0**, and the AGPL network clause then covers the entire application. That is a real product
decision, not a formality. The alternative — cores behind a process/plugin boundary, each keeping its own
license — is examined in `ARCHITECTURE.md`.

The "or-later" status of the GPLv2 projects is load-bearing: GPL-2.0-**only** code cannot be combined
with the GPLv3/AGPLv3 projects at all. Dolphin states it explicitly
(`SPDX-License-Identifier: GPL-2.0-or-later`, `dolphin-ios/Source/Core/Core/Core.cpp:2`); PPSSPP says
"version 2.0 or later versions" (`PPSSPP/Core/Core.cpp:5`).

### A GPL-2.0-only component is already present, and it is already a violation [verified]

**Gambatte**, the Game Boy/GBC core inside `Folium/Kiwi`, is GPL-2.0-**only**:

> "it under the terms of the GNU General Public License version 2 as published by the Free Software
> Foundation" — `Folium/Kiwi/System/gambatte.cpp:4-6` (no "or later" grant)

Folium ships under GPL-3.0 (`Folium/LICENSE`). A GPL-2.0-only core cannot legally be linked into a
GPL-3.0 binary, so **this conflict pre-exists Avalon** — it is inherited, not introduced. Avalon must
not carry it forward. Options: drop Gambatte, or replace GB/GBC with SameBoy (MIT) or Gambatte's
GPLv2-only terms accepted by keeping Avalon at GPLv2 (which AGPL/GPLv3 components then forbid).
**Selected: replace the core.** This is encoded and tested in `Sources/AvalonCore/Provenance/License.swift`
and `Tests/AvalonCoreTests/LicenseTests.swift`.

Two further inherited hazards, both verified:
- `Folium/Plum/System/core/clown68000/…/clown68000.c:2-8` is **AGPL-3.0-or-later** — stronger than the
  GPL-3.0 umbrella it sits under.
- `Folium/SharedDependencies/Sources/osa` embeds Nintendo 3DS system files (`shared_font`, `mii`,
  `country_list`) as C arrays. These are copyrighted Nintendo data, not code Avalon may redistribute.
  **Excluded from Avalon unconditionally.**

---

## 4. Capability matrix — strongest implementation per subsystem [analysis]

Chosen on technical merit and integration cost, not project reputation. "Cost" is the honest
barrier to getting it into Avalon.

| Subsystem | Strongest | Why | Cost |
|---|---|---|---|
| **Core plugin contract** | Delta `EmulatorBridging` | ~20 methods, proven across 7 cores, extensible string `GameType` | Low — adapted already. Video half replaced |
| **GPU surface handoff** | Folium `set_screens` / iPSX2 `layerClass` | Five projects converged on it independently | Low — design adopted |
| **Native Metal renderer** | **iPSX2** | Only native Metal GS in the repo: `GS/Renderers/Metal`, 8 `.metal` shaders, 2,567 lines; adopts the UIView's own `CAMetalLayer` (`GSDeviceMTL.mm:778-782`) | Medium — GPL-3.0 |
| **Graphics backend abstraction** | **dolphin-ios / Fin** | `AbstractGfx`, `AbstractPipeline`, `AsyncShaderCompiler`, `GraphicsModSystem` — each returns **0 hits across all seven sibling projects** | High — `VideoCommon` has 533 refs to `g_gfx`/`g_ActiveConfig` globals |
| **Shader/pipeline cache** | PPSSPP | Integer permutation key → variant bitmask → two-level disk cache → background compile bucketed by shader pair → blocking warm-up at load | Low — copy the *design*; maps onto `MTLBinaryArchive` |
| **Post-process shaders** | **Fin** | `.slangp` RetroArch chains (`VideoCommon/Slang/`, 8 files) → glslang → SPIRV-Cross → MSL. Unlocks the whole RetroArch shader ecosystem | Medium — hardcoded to `APIType::Metal` |
| **Shader authoring** | Play! Nuanceur | C++ eDSL emitting SPIR-V *and* HLSL from one AST — proven multi-target | Medium — submodule absent, one-author library |
| **Fast path without JIT** | **Fin** | Cached interpreter rewritten 480→1,769 lines with ~34 inlined opcodes and a per-callsite block inline cache | Medium — best "no-JIT" asset in the repo |
| **ARM64 JIT (PS2)** | iPSX2 | Real ARM64 recompiler, 3,804 vixl call sites | High — 88 MMI opcodes still interpreted; only 5 allocatable GPRs |
| **iOS JIT acquisition** | **iPSX2 + dolphin-ios** | iPSX2's 4-mode `DarwinMisc.cpp:645-860`; dolphin-ios's ptrace/AltServer/JitStreamer/TXM ladder | Medium — must be hoisted to a platform service |
| **Dual RW/RX code memory** | MeloNX | `vm_remap` aliasing, ~20 lines, directly portable to C++ | Low |
| **Guest memory / MMU** | MeloNX `Ryujinx.Memory` | Fault-address patching to get 4 KB tracking on 16 KB Apple pages | Design only — C# |
| **Mirrored guest RAM** | PPSSPP `MemArenaDarwin` | `vm_allocate`/`vm_remap` + iOS base-address probing | Low — take near-verbatim |
| **Audio mixer** | PPSSPP `GranularMixer` / Fin "Bell Audio" | 6-point Hermite, 50%-overlap granules, queue-depth rate control (not pitch bending); Fin adds NEON mixing, underrun envelope, dither | Low — both GPL-2.0-or-later |
| **Frame pacing** | **none — written for Avalon** | Every project here lacks display phase lock; PPSSPP hardcodes 60 Hz on iOS | Done — `Core/FramePacer.swift` |
| **Frame conversion** | **none — written for Avalon** | Folium's per-frame `CGImage` path is the thing to replace | Done — `Sources/AvalonPixel`, 7.5× on PS1 geometry |
| **Driver bug database** | PPSSPP `thin3d.h:322-352,583-643` | `DeviceCaps` + `Bugs`: a decade of mobile-driver scar tissue as data | Low — copy near-verbatim |
| **Input mapping** | Delta | Per-(player, gameType, controllerType) mapping; one receiver graph serving touch, MFi and keyboard | Low |
| **Virtual pad editor** | Manic EMU | 1,735-line visual editor writing `.manicskin`; iPSX2's normalized-coords model is the cleaner data design | Medium |
| **Game identification** | Delta | SHA1 + bundled OpenVGDB, offline and deterministic | Low — vs Manic's network scraping + LLM call |
| **Archive/disc formats** | Manic EMU | zip/7z/rar, chd/cso/pbp/rvz/m3u | Low |
| **Settings/feature flags** | Delta `DeltaFeatures` | `@Feature`/`@Option` wrappers auto-generating SwiftUI; 878 LOC, self-contained, zero Delta deps | Low — lift wholesale |
| **Per-game config** | Manic EMU | Typed columns, 3-scope game/system/global | Low — vs Delta's opaque 4-key dictionary |
| **HLE BIOS (PS2)** | **Play!** | ~35 HLE'd IRX modules + EE kernel; **no BIOS dump required**, unlike PCSX2. HLE-first with real-IRX fallback | High value, medium cost — **BSD-2** |
| **VU recompilation** | Play! | Per-field stall modelling, dead-flag elimination, cross-block integer-branch-delay compensation, deferred XGKICK | High — port algorithms, not code |
| **Per-game fixes** | Play! `GameConfig.xml` | Declarative, keyed by **block content hash** rather than address | Low — generalizes to every core |
| **Portable support lib** | PPSSPP `Common/` | 354 files with only 13 `Core/` includes across 4 files — genuinely decoupled | Low, except `CPUDetect` (GPL-2.0-only) |
| **Thread pool** | PPSSPP `Common/Thread` | Task pool with 3 task classes, `Promise`, `ParallelLoop` — 1,336 LOC | Low |
| **Switch emulation** | MeloNX | Only Switch core available | **Plugin only** — NativeAOT .NET dylib, cannot merge |

### The two PS2 projects are complementary, not competing

This is the clearest case of the brief's "combine two excellent implementations solving different
aspects of the same problem":

- **iPSX2** has the native Metal renderer and a working ARM64 JIT, but **requires a BIOS dump** and is GPL-3.0.
- **Play!** has a complete **HLE BIOS** (no dump, `Source/ee/PS2OS.cpp` + `Source/iop/IopBios.cpp`),
  the best VU analysis passes anywhere here, and is **BSD-2** — but renders through MoltenVK/GL and
  its iOS story depends on JIT it cannot obtain.

Avalon's PS2 path takes Play!'s HLE BIOS and VU analysis with iPSX2's Metal GS approach and Avalon's
JIT service. That removes the BIOS-dump wall, which is a legal and UX barrier for any mainstream
distribution.

## 5. Integration status

See `INTEGRATION-STATUS.md`. Terms used there mean exactly what §12 of the project brief says they mean:
discovered → analyzed → selected → adapted → partially integrated → integrated → tested → validated.

## 6. Known limitations

- No full Xcode on the build machine (Command Line Tools only): no iOS SDK, no `.xcodeproj` builds,
  no CMake. Avalon's foundation is therefore a Swift Package, buildable and testable with
  `swift build` / `swift test` on macOS. iOS app targets cannot be compiled or run here.
- Delta's core protocol source is absent (submodules), so its contract must be reconstructed from use.
- Manic EMU's libretro cores are binaries; their source is not in this repository.
