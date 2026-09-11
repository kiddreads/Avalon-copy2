# Avalon — Architecture

Phase 2 deliverable. Every decision below cites the source evidence that forced it.

---

## The decision that shapes everything: how a core receives its screen

Five of the projects in this repository independently solved the same problem, and **all five arrived
at the same answer**: the frontend creates a `CAMetalLayer` and hands the core an opaque pointer to it,
then gets out of the way.

| Project | Mechanism | Evidence |
|---|---|---|
| Folium | `cytrus::set_screens(void* layer, h, w, secondary)`, stored as `CA::MetalLayer*` via metal-cpp, given to Vulkan as `render_surface` | `Folium/Cytrus/System/bridge.cpp:276-286`, `emu_window_vk.cpp:43-48` |
| MeloNX | Swift `Unmanaged.passUnretained(metalLayer).toOpaque()` → `set_native_window` → `vkCreateMetalSurfaceEXT` | `MeloNX/src/MeloNX/MeloNX/UI/Emulation/Metal/MetalView.swift:178-193`, `Ryujinx.Library/Window/MoltenVKWindow.cs:83-109` |
| iPSX2 | `UIView.layerClass = CAMetalLayer`; the Metal backend **adopts the view's existing layer** rather than making one | `iPSX2/iPSX2/cpp/ios_main.mm:73-89`, `GS/Renderers/Metal/GSDeviceMTL.mm:778-782` |
| Manic EMU | Bypasses its own core protocol with a non-protocol `start(…metalView:…)` handing over the raw layer | `Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Cores/ThreeDS.swift:303-362` |
| PPSSPP | `+layerClass → CAMetalLayer`, layer passed to `InitSurface(WINDOWSYSTEM_METAL_EXT, …)` | `PPSSPP/ios/ViewControllerMetal.mm:71,278` |

Delta is the control case that proves the point. Its `DeltaCore` contract has **no** surface channel —
only `VideoRendering` plus a `videoFormat.dimensions` fixed at init, surfaced to views as a `CIImage`
(`Delta/Delta/Emulation/PreviewGameViewController.swift:210`). It therefore cannot host a GPU-native
core, and **Manic EMU — which is built on DeltaCore — had to route around its own protocol to run
Citra** (`ThreeDS.swift:303-362`, which declares a fake `videoFormat` at `:158`).

> **Decision 1.** Avalon's core contract is *surface-negotiated*, not buffer-returning. A core is
> handed a drawable surface plus a scale factor and told when it resizes or is invalidated. The
> CPU-framebuffer case (NES, GB, Genesis …) is **one implementation of that contract**, not the
> contract itself — Avalon owns a single shared Metal presenter that uploads those frames.
>
> This inverts Delta's video layer while keeping the rest of its contract, which is genuinely good.

### Why the shared presenter matters

Folium's software cores each convert `uint32_t*` → `CGImage` → `UIImage` → `UIImageView.image` every
frame on the main actor (`Folium/Folium/Controllers/Emulation/KiwiController.swift:381-408`). Mandarine converts the **entire
1024×512 PS1 VRAM** to a 24-bit `CGImage` per frame and only then crops
(`MandarineController.swift:340-352`). One shared presenter replaces all of it and gives
every software core free scaling, filtering and vsync.

This is built and measured. `Sources/AvalonPixel` converts straight into a texture staging buffer
with a NEON path (verified against the scalar path across the entire 16-bit input space for both
16-bit formats — `FramePresenterTests.swift`). Measured on this machine, `swift run -c release
avalon-bench`:

| case | per frame |
|---|---|
| NES 256x240 RGB565, full frame | 17.2 us |
| GBA 240x160 RGB565, full frame | 6.7 us |
| **PS1 VRAM 1024x512 — convert whole surface then crop (Folium's approach)** | **109.8 us** |
| **PS1 VRAM 1024x512 — region blit of the 320x240 visible window (Avalon)** | **14.6 us** |

A **7.5x** reduction for the Mandarine geometry, before counting the `CGImage`/`UIImage`
allocation and the main-actor hop that Folium additionally pays on every frame.

---

## Decision 2: keep DeltaCore's *other* three surfaces

The lifecycle/input/state/cheat half of `EmulatorBridging` is small, complete and proven across seven
shipping cores. Recovered verbatim from Manic EMU's conformances (DeltaCore itself is an uncheckout
submodule) at `Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Cores/EmulatorBridgingBase.swift:9-79`:

`start/stop/pause/resume`, `runFrame(processVideo:)`, `activateInput/deactivateInput/resetInputs`,
`saveSaveState/loadSaveState`, `saveGameSave/loadGameSave`, `addCheatCode/resetCheats/updateCheats`,
optional `readMemory` (which is how Delta drives RetroAchievements core-agnostically —
`Delta/Delta/RetroAchievements/AchievementsTracker.swift:181`).

Avalon adopts this shape, with two corrections:
- **No singletons.** `FDSEmulatorBridge.shared`, `ThreeDSEmulatorBridge.shared`,
  `LibretroCore.sharedInstance()` (`Cores/FDS.swift:93`, `ThreeDS.swift:227`) make one instance per
  core a hard ceiling. Avalon's cores are instantiable.
- **`GameType` stays an extensible string ID** (`GameType("public.aoshuang.game.fds")`,
  `Cores/FDS.swift:14`) so new systems need no change to the core protocol.

---

## Decision 3: JIT is a platform service, not a per-core concern

This is the cross-cutting conflict the reconnaissance surfaced, and it is load-bearing.

- **MeloNX reserves 512 MB–1 GB of JIT cache at startup and then calls `BreakJITDetach()`**, after
  which *no further JIT memory can be mapped in that process*
  (`Ryujinx.Cpu/LightningJit/Cache/DualMappedNoWxCache.cs:15`, `Ryujinx.Memory/MemoryBlock.cs:118-126`).
- **iPSX2 has the most complete iOS JIT strategy in the repository**: a four-mode scheme
  (Simulator / TXM / non-TXM / legacy) with TXM detection by globbing for
  `Ap,TrustedExecutionMonitor.img4`, `kern.osproductversion` version discrimination, `MAP_JIT` +
  `pthread_jit_write_protect_np` with an `mprotect` fallback, dual RX/RW `vm_remap` mapping, and a
  `brk #0x69` debugger handshake wrapped in a `sigsetjmp`/SIGTRAP net so an unhandled trap degrades
  instead of crashing (`iPSX2/iPSX2/cpp/common/Darwin/DarwinMisc.cpp:645-860`).
- **PPSSPP uses plain `mprotect` RW↔RX flipping, not `MAP_JIT`** — zero hits for `MAP_JIT` or
  `pthread_jit_write` — and its code buffers are explicitly non-nestable, i.e. **single-threaded
  codegen only** (`PPSSPP/Common/CodeBlock.h:96-148`, comment at `:105`).
- **Fin removed JIT entirely** and runs Dolphin interpreted (`Fin/Readme.md`).

Four cores, four incompatible JIT strategies, one process-global resource.

> **Decision 3.** Avalon owns JIT acquisition, the W^X regime, and code-cache reservation as a single
> platform service. Cores request code memory from Avalon; none of them probes, reserves, or detaches
> on its own. Without this, *whichever core starts second silently loses its JIT*.

The design to implement is iPSX2's four-mode strategy plus MeloNX's `vm_remap` dual-mapping
(`DualMappedJitAllocator.cs:85-105`) and its graceful no-debugger fallback — a SIGTRAP handler that
does `pc += 4; x0 = 0` so a missing debugger returns NULL instead of crashing
(`MeloNX/src/MeloNX/MeloNX/Common/JIT26Breakpoint.swift:10-15`). Note: taking iPSX2's *code* makes the consumer
GPL-3.0; the technique should be re-implemented from public Apple APIs if App Store viability matters.

---

## Decision 4: cores are engines behind a boundary, not merged into one core

The brief allows for this explicitly, and the code demands it:

- **MeloNX cannot be merged at any price.** It is .NET 10 **NativeAOT** cross-compiled to `ios-arm64`,
  shipping as `Ryujinx.Library.dylib` with a flat 30-function C ABI
  (`Ryujinx.Library.csproj:5,12-13`, `MeloNX/src/MeloNX/MeloNX/Core/Ryujinx.swift:391-479`). The dylib statically
  contains an entire .NET runtime — one GC, one thread pool, one BCL per image. 4,007 `.cs` files.
  There is no path from that to C++. It is *already* a plugin; Avalon should treat it as one.
- The C++ cores (Dolphin family, PPSSPP, PCSX2, Play!) share no CPU architecture, no memory model and
  no renderer. "One universal CPU core" is not a real objective; PowerPC Gekko and MIPS R5900 do not
  merge.

> **Decision 4.** Avalon is a **common frontend and platform-services layer over system-specific
> engines**, each behind one stable Swift-facing contract. What unifies is everything *around* the
> emulation: surface, presenter, input, audio, storage, save states, configuration, JIT, library, UI.

---

## Decision 5: Swift↔C++ directly, no Objective-C++ shim layer

Folium demonstrates Swift 6 `.interoperabilityMode(.Cxx)` calling plain C++ namespaces of free
functions, with `Unmanaged.passUnretained(self).toOpaque()` as the callback context and reverse
interop (`<Module>-Swift.h`) letting C++ ask Swift for paths
(`Folium/Kiwi/System/bridge.cpp:24-29,110-141`). This is materially less friction than Delta's `@objc`
protocol or iPSX2's ObjC++ bridge. Avalon adopts it, but behind **one** protocol rather than Folium's
per-core copy-paste — `Folium/Mango/bridge.h` and `Folium/Durian/bridge.h` are byte-identical after
substituting the namespace name.

---

## Licensing consequence

`Sources/AvalonCore/Provenance/` encodes this and `Tests/AvalonCoreTests/LicenseTests.swift` enforces it.

The combinable set — Play! (BSD-2), Dolphin family + PPSSPP (GPL-2.0-or-later), Folium, iPSX2
(GPL-3.0), Delta, Manic EMU (AGPL-3.0) — lands a combined work at **AGPL-3.0**, whose §13 network
clause then covers the whole application.

Four components are **excluded** because they cannot legally be combined:
1. **Gambatte** (`Folium/Kiwi`), GPL-2.0-**only** — already in conflict with Folium's own GPL-3.0.
2. **PPSSPP's 10 GPL-2.0-only files** inherited from 2003-era Dolphin; `CPUDetect.h` is included by
   62 files including the ARM64 emitter Avalon most wants. Rewrite detection rather than inherit it.
3. **Manic EMU's `nonCommercialCores`** (PicoDrive, FBNeo, Snes9x) — a non-commercial term is an
   additional restriction GPL §7 forbids.
4. **`Folium/SharedDependencies/Sources/osa`** — embedded Nintendo 3DS system files. Not code.

**Unresolved:** MeloNX's `LICENSE.txt` is verbatim **MIT** while its README claims GPLv3
(`MeloNX/LICENSE.txt` vs `MeloNX/README.md:13,218`). This must be settled with the author before
Avalon ships anything derived from it.

---

## Resulting structure

```
Avalon/
├── Sources/
│   ├── AvalonCore/          Core contract, session lifecycle, provenance, licensing   [building]
│   ├── AvalonPlatform/      JIT service, memory, W^X, filesystem, lifecycle           [planned]
│   ├── AvalonGraphics/      Shared Metal presenter, surface negotiation, caps/bugs DB [planned]
│   ├── AvalonAudio/         Granular mixer, output backend                            [planned]
│   ├── AvalonInput/         Controller abstraction, mapping, virtual pad              [planned]
│   └── AvalonLibrary/       Game scanning, identification, metadata, save states      [planned]
└── docs/                    ENGINEERING-MAP.md, ARCHITECTURE.md, INTEGRATION-STATUS.md
```

Subsystem ownership is deliberate: nothing in `AvalonCore` may import a frontend type, and no core
may reach the presenter except through the surface contract.
