# Avalon — Integration Status

Stages mean exactly what the project brief §12 says. Nothing is described as integrated because a
file was copied, an interface exists, or a stub compiles.

Legend: **discovered → analyzed → selected → adapted → partially integrated → integrated → tested → validated**

## Avalon subsystems

| Subsystem | Stage | Evidence |
|---|---|---|
| Licensing & compatibility model | **tested** | `Provenance/License.swift`; 7 tests |
| Source-project registry | **tested** | `Resources/projects.json` (10 projects, 5 hazards); 8 tests |
| Attribution / NOTICE generation | **tested** | `Provenance/NoticeGenerator.swift`; generated `NOTICE.md` |
| Core contract (`EmulatorCore`) | **adapted** | Derived from Delta's `EmulatorBridging`; compiles; no core implements it yet |
| Surface negotiation | **adapted** | `Core/RenderSurface.swift`; design settled and cited, no Metal backend yet |
| JIT arbitration (policy) | **tested** | `Platform/JITService.swift`; 5 tests on the real MeloNX/PPSSPP conflicts |
| **JIT executable memory** | **validated** | `Sources/AvalonJIT` + `Platform/CodeCache.swift`; 8 tests **generate and execute real ARM64** |
| **Frame conversion / presenter** | **validated** | `Sources/AvalonPixel` (C + NEON) + `Graphics/FramePresenter.swift`; exhaustive SIMD-vs-scalar over the full 16-bit space; benchmarked 7.5× on PS1 geometry |
| **Audio mixer / resampler** | **validated** | `Sources/AvalonAudio`; adapted from Dolphin's granular mixer; measured 2570× lower RMS error than linear |
| Frame pacing | **tested** | `Core/FramePacer.swift`; 7 tests across 59.94/59.727/50 Hz, ProMotion, stalls |
| Configuration (3-scope) | **tested** | `Configuration/Configuration.swift`; 6 tests |
| System-files gate | **tested** | `Storage/SystemFiles.swift`; 6 tests incl. Play!-vs-iPSX2 core selection |
| Input abstraction | **tested** | `Input/Input.swift`; 7 tests using Folium's real per-core encodings |
| Graphics quirks / capabilities | **tested** | `Graphics/GraphicsQuirks.swift`; 6 tests; content sourced from 5 projects |
| Logging | **tested** | `Diagnostics/Log.swift`; 5 tests |
| Metal texture upload | *selected* | Presenter is Metal-free by design so it tests off-device; upload is platform code |
| Shader/pipeline cache | *selected* | PPSSPP's architecture chosen; not yet written |
| Game library / identification | *analyzed* | Delta's SHA1 + offline OpenVGDB over Manic's network scraping |

## Source projects

| Project | Stage | Note |
|---|---|---|
| Delta | **analyzed** | Core contract recovered and adapted. App shell not used. |
| Manic EMU | **analyzed** | Flex skin editor and per-game typed config selected for later. |
| Folium | **analyzed** | Surface-handoff seam selected; app layer rejected (7,500-line copy-paste tree). |
| PPSSPP | **analyzed** | `DeviceCaps`/`Bugs` DB, shader-cache architecture, `Common/Thread` selected. |
| Play! | **analyzed** | HLE BIOS + VU analysis passes selected. BSD-2 makes it uniquely reusable. |
| iPSX2 | **analyzed** | Native Metal GS and the Darwin JIT strategy selected. |
| dolphin-ios | **analyzed** | Newest Dolphin base. AbstractGfx abstraction + iOS JIT ladder selected. |
| Fin | **analyzed** | `.slangp` shader chains, cached-interpreter rewrite, Bell Audio selected. |
| iCube | **analyzed — recommended for removal** | Stale unbranded copy of dolphin-ios; 0 occurrences of its own name in its source. Contributes nothing. |
| MeloNX | **analyzed** | Cannot be merged. Plugin-only via its existing C ABI. License unresolved. |

## Pending decision

**Removing `iCube`** would delete 7,427 files / 99.9 MB of verified pure duplication. Evidence is in
ENGINEERING-MAP.md §1. Git history retains it either way. Awaiting the repository owner's call.

## Known gaps

- No core implements `EmulatorCore` yet, so no game runs. Every subsystem it would use is built
  and tested; what is missing is a core, and the iOS app target to host one.
- No iOS app target exists; the build machine has Command Line Tools only (no Xcode, no iOS SDK).
- MeloNX's license contradiction (MIT file vs GPLv3 README) is unresolved and blocks derivation.
