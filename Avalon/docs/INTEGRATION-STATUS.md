# Avalon — Integration Status

Stages mean exactly what the project brief §12 says. Nothing is described as integrated because a
file was copied, an interface exists, or a stub compiles.

Legend: **discovered → analyzed → selected → adapted → partially integrated → integrated → tested → validated**

## Avalon subsystems

| Subsystem | Stage | Evidence |
|---|---|---|
| Licensing & compatibility model | **tested** | `Sources/AvalonCore/Provenance/License.swift`; 7 tests in `LicenseTests.swift` |
| Source-project registry | **integrated** | `Resources/projects.json` (10 projects, 5 hazard entries), `ProjectRegistry.swift` |
| Core contract (`EmulatorCore`) | **adapted** | Derived from Delta's `EmulatorBridging`; compiles; no core implements it yet |
| Surface negotiation | **adapted** | `RenderSurface.swift`; the design is settled and cited, no Metal backend yet |
| JIT arbitration | **tested** | `Platform/JITService.swift`; 5 tests covering the real MeloNX/PPSSPP conflicts |
| Frame pacing | **tested** | `Core/FramePacer.swift`; 7 tests across 59.94/59.727/50 Hz guests, ProMotion, stalls. Written, not harvested — no project here phase-locks to the display |
| Frame conversion / presenter | **tested** | `Sources/AvalonPixel` (C + NEON) + `Graphics/FramePresenter.swift`; 7 tests incl. exhaustive SIMD-vs-scalar; benchmarked (7.5x on the PS1 VRAM case) |
| Metal texture upload | *selected* | Presenter is deliberately Metal-free so it tests off-device; upload belongs in AvalonPlatform |
| Audio (granular mixer) | *selected* | PPSSPP `Core/HW/GranularMixer.*`, GPL-2.0-or-later; not yet adapted |
| Input mapping | *selected* | Delta's `GameController`/`Input` receiver graph; not yet adapted |
| Game library / identification | *analyzed* | Delta's SHA1 + offline OpenVGDB chosen over Manic's network scraping |

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

- No core implements `EmulatorCore` yet, so nothing renders, plays audio or accepts input.
- No iOS app target exists; the build machine has Command Line Tools only (no Xcode, no iOS SDK).
- MeloNX's license contradiction (MIT file vs GPLv3 README) is unresolved and blocks derivation.
