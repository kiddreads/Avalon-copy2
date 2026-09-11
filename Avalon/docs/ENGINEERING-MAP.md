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

### Three projects are the same emulator [verified]
`dolphin-ios`, `iCube` and `Fin` are all Dolphin derivatives. `Fin/Readme.md` states outright that it is
a fork of DolphiniOS. `dolphin-ios` *is* DolphiniOS. `iCube` carries an identical `Externals/` manifest
and near-identical file count (7,427 vs 7,381) and byte size (99.9 vs 99.2 MB).
See §"Dolphin family" for the measured divergence.

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

## 4. Component map — which Avalon subsystem comes from where

*Populated in Phase 2. Nothing is claimed here until it is actually building inside Avalon.*

## 5. Integration status

See `INTEGRATION-STATUS.md`. Terms used there mean exactly what §12 of the project brief says they mean:
discovered → analyzed → selected → adapted → partially integrated → integrated → tested → validated.

## 6. Known limitations

- No full Xcode on the build machine (Command Line Tools only): no iOS SDK, no `.xcodeproj` builds,
  no CMake. Avalon's foundation is therefore a Swift Package, buildable and testable with
  `swift build` / `swift test` on macOS. iOS app targets cannot be compiled or run here.
- Delta's core protocol source is absent (submodules), so its contract must be reconstructed from use.
- Manic EMU's libretro cores are binaries; their source is not in this repository.
