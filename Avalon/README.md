# Avalon

A unified emulation platform assembled from the strongest compatible technology in this repository.

Avalon is **not** a wrapper around ten emulators sitting side by side. It is a common frontend and
platform-services layer over system-specific engines, with one core contract, one renderer path, one
JIT service, one presenter, and one place where licensing is decided.

## Status

Phases 1–3 complete (discovery, architecture, foundation); Phase 4 (core integration) underway.
`docs/INTEGRATION-STATUS.md` tracks every subsystem honestly — *discovered → analyzed → selected →
adapted → partially integrated → integrated → tested → validated*. Nothing is called integrated
because a file was copied or an interface compiles.

**No core implements the contract yet**, so nothing renders a game. What does exist is built, tested
and measured.

## Build

Requires Swift 5.9+. Command Line Tools are enough — no Xcode, no CMake.

```sh
swift build
swift test                      # 78 tests
swift run -c release avalon-bench     # frame-conversion benchmark
swift run avalon-notice NOTICE.md     # regenerate attribution
```

## What is here

| Path | What it is |
|---|---|
| `Sources/AvalonCore/Core/` | The core contract, surface negotiation, system IDs, frame pacer |
| `Sources/AvalonCore/Graphics/` | Shared frame presenter |
| `Sources/AvalonCore/Platform/` | JIT arbitration service |
| `Sources/AvalonCore/Provenance/` | Licence model, source registry, notice generation |
| `Sources/AvalonCore/Configuration/` | Three-scope settings (game > system > global) |
| `Sources/AvalonCore/Input/` | Normalized controls, per-core encoding maps, bindings |
| `Sources/AvalonCore/Storage/` | Required-system-file gate and core selection |
| `Sources/AvalonCore/Diagnostics/` | Logging |
| `Sources/AvalonPixel/` | Pixel conversion hot path (C + NEON) |
| `Sources/AvalonJIT/` | Executable memory: MAP_JIT, vm_remap dual mapping, W^X |
| `Sources/AvalonAudio/` | Granular mixer, 6-point Hermite resampler |
| `docs/ENGINEERING-MAP.md` | Repository inventory, duplication, licensing, capability matrix |
| `docs/ARCHITECTURE.md` | The five architectural decisions and the evidence forcing each |
| `docs/INTEGRATION-STATUS.md` | Per-subsystem and per-project integration stage |

## The three findings that shaped it

**Video must be surface-negotiated.** Five projects here — Folium, MeloNX, iPSX2, Manic EMU and
PPSSPP — independently ended up handing their core an opaque `CAMetalLayer`. Delta, the one project
with no surface channel, cannot host a GPU-native core; its own derivative Manic EMU has to bypass
the protocol to run Citra. Avalon hands cores a surface rather than taking back a buffer, and treats
the CPU-framebuffer case as one implementation of that contract.

**JIT is a process-global resource.** Four cores here use four incompatible strategies, and MeloNX
permanently closes the process's ability to map executable memory after reserving up to 1 GB. Left
alone, whichever core starts second silently loses its JIT. Avalon arbitrates it.

**Licensing is decisive, and partly broken before Avalon touches it.** Gambatte inside Folium is
GPL-2.0-only within a GPL-3.0 project. PPSSPP carries ten GPL-2.0-only files under the ARM64 emitter
most worth harvesting. Manic EMU gates non-commercial cores. Folium embeds Nintendo 3DS system files.
MeloNX ships an MIT licence file while its README claims GPLv3. These are encoded in
`Sources/AvalonCore/Provenance/` and enforced by tests, not kept in a document.

## Licence

Avalon's own code is AGPL-3.0-or-later, which is what the combined work must be. See `NOTICE.md`,
generated from the registry.
