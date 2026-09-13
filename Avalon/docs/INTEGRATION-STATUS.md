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
| **Core contract (`EmulatorCore`)** | **validated** | Derived from Delta's `EmulatorBridging`. `Cores/Chip8Core.swift` implements it fully; 9 tests run real ROMs and verify pixels, flags, input, audio and save states |
| **Run loop (`CoreSession`)** | **validated** | `Core/CoreSession.swift` composes core + pacer + presenter + router + audio; 9 tests; `swift run avalon-run` renders a real ROM |
| **CHIP-8 reference core** | **validated** | `Sources/AvalonChip8` (C) + `Cores/Chip8Core.swift`; a complete system — CPU, memory, framebuffer, keypad, timers |
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
| Touch control layouts | **tested** | `Controls/TouchLayout.swift` + `Resources/controls.json`; 11 platforms, 120 controls |
| Layout solver | **tested** | `Controls/LayoutSolver.swift`; resolves onto any aspect ratio; 6 device profiles |
| Layout verifier | **tested** | `Controls/LayoutVerifier.swift`; 132 platform×device×mode checks, 0 fatal |
| Touch routing | **tested** | `Controls/TouchRouter.swift`; 13 tests incl. an end-to-end press into a core encoding |
| Control skins | **tested** | `Controls/ControlSkin.swift` + `Resources/controlskins.json`; 22 skins from muffin |
| libretro frontend | **tested** | `Sources/AvalonLibretro` + `Cores/LibretroCore.swift`; 7 tests against a real libretro core, not a mock |
| iOS build of the package | **tested** | GitHub Actions compiles AvalonCore against the iOS SDK for simulator and device; the first run found `pthread_jit_write_protect_np` is macOS-only |
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
| Genesis Plus GX | **integrated, tested** | `GenesisPlusGXSpec` + `GenesisPlusGXInputMap.swift`; `GenesisPlusGXCoreTests` proves load/run/save-state against the compiled, linked core; the app selects it for `.genesis` games |
| Nestopia | **integrated, tested** | `NestopiaSpec` + `NestopiaInputMap.swift`; `NestopiaCoreTests` proves load/run/save-state against the compiled, linked core; a C++ target sharing one binary with Genesis Plus GX required namespacing 262 internal libretro-common symbols too, not just the RETRO_API surface |
| mGBA | **integrated, tested** | `MGBASpec` + `MGBAInputMap.swift`; `MGBACoreTests` proves load/run/save-state; removes the Gambatte (GPL-2.0-only) blocker for GB/GBC/GBA entirely |
| Nintendo 3DS (Citra) | **analyzed** | GPL-2.0-or-later verified; dynarmic JIT off on arm64, a software renderer exists, but cryptopp + libressl are real load-bearing dependencies and the core is 61 MB. A different scale of task than the three integrated libretro cores; see docs/ENGINEERING-MAP.md §5f. |
| iCube | **analyzed — snapshot is wrong, needs re-merging** | `Provenance-Emu/iCube`, "Dolphin for iOS, re-reborn", a fork of `brand175/dolphin-ios` and the most recently developed of the three Dolphin lineages here (upstream 2026-09-08). The copy in this repository came from its abandoned `master` and is 167 days stale. Earlier recommendation to remove it is withdrawn. |
| MeloNX | **analyzed** | Cannot be merged. Plugin-only via its existing C ABI. License unresolved. |

## Sources outside this repository

| Project | Licence | Stage | What Avalon took |
|---|---|---|---|
| cemu-ios-muffin | MPL-2.0 | **adapted (skin model only)** | The named-colour-token skin model and its 22 colour presets, re-expressed as `Resources/controlskins.json`. No muffin code is in Avalon. Sibling repo, not part of this tree. MPL §3.3 permits it in an AGPL build because no file under `cemu-ios-muffin/src/ios/App/` carries the Exhibit B notice. |

Integrating anything further from muffin is **on hold at the repository owner's request** — they are
still working in that repo and will say when it is ready.

## Pending decision

**Re-merge `iCube` from `develop`.** `.github/workflows/merge-emulators.yml` now pins it, so:

```
gh workflow run merge-emulators.yml -f only=iCube
```

This rewrites ~800 MB of history into the repository, so it is the owner's call to fire.

**MeloNX** is parked at the owner's request while its licence contradiction is sorted out.

## Known gaps

- **Avalon runs.** `swift run avalon-run` loads a ROM, executes it, and prints the framebuffer the
  presenter produced. The core driving it is CHIP-8 — a real system, but a small one. No core for
  the *large* systems (GameCube, PS2, PSP, 3DS, Switch) is wired up yet; those are Phase 4 proper,
  and each is a substantial port rather than a binding.
- No iOS app target exists; this machine has Command Line Tools only (no Xcode, no iOS SDK), so
  `.xcodeproj` targets and on-device runs cannot be built or verified here.
- **The control layouts are geometry and routing, not pixels.** Every layout resolves, verifies and
  routes touches, and `swift run avalon-controls` prints the numbers for all 11 platforms on 6
  device profiles. Nothing *draws* them: rendering is the platform layer's job and needs the iOS
  app target that cannot be built on this machine.
- No Metal backend yet. The presenter deliberately holds no Metal types so it tests off-device;
  texture upload is the platform layer's job and is not written.
- No iOS app target exists; the build machine has Command Line Tools only (no Xcode, no iOS SDK).
- MeloNX's license contradiction (MIT file vs GPLv3 README) is unresolved and blocks derivation.
