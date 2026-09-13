# Avalon — Notices and Attribution

Generated from `Sources/AvalonCore/Resources/projects.json`. Do not edit by hand.

Repository snapshot: kiddreads/Avalon-copy2 @ 6fa7b92 (2026-09-10)

Avalon is assembled from the projects below. Each retains its own copyright and licence;
this notice records them as those licences require.
**Combined work licence:** AGPL-3.0-or-later

Because the combined work is AGPL-3.0, §13 applies: anyone interacting with an
Avalon component over a network must be offered the corresponding source.

## Included projects

### Delta — AGPL-3.0-or-later

- Source: https://github.com/rileytestut/Delta
- Copyright: Riley Testut, AltStore LLC
- Licence text: `Delta/COPYING`
- Systems: NES, SNES, N64, GB, GBC, GBA, NDS, Genesis

### Fin — GPL-2.0-or-later

- Upstream: DolphiniOS -> Dolphin
- Source: https://github.com/OatmealDome/dolphiniOS
- Copyright: Dolphin Emulator Project
- Licence text: `Fin/COPYING`
- Systems: GameCube, Wii

### Folium — GPL-3.0-or-later

- Source: https://github.com/jarrodnorwell/Folium
- Copyright: Jarrod Norwell
- Licence text: `Folium/LICENSE`
- Systems: 3DS, PS1, NDS, GB, GBC, GBA, ColecoVision, Genesis, NES, SNES, WonderSwan

### Manic EMU — AGPL-3.0-or-later

- Copyright: Manic EMU authors
- Licence text: `Manic EMU/Manic EMU/LICENSE`
- Systems: 40+ via libretro

### MeloNX — MIT

- Upstream: Ryujinx
- Source: https://github.com/MeloNX-Emu/MeloNX
- Copyright: Ryujinx contributors, MeloNX contributors
- Licence text: `MeloNX/LICENSE.txt`
- Systems: Nintendo Switch

### PPSSPP — GPL-2.0-or-later

- Source: https://github.com/hrydgard/ppsspp
- Copyright: Henrik Rydgard, PPSSPP Project
- Licence text: `PPSSPP/LICENSE.TXT`
- Systems: PSP

### Play! — BSD-2-Clause

- Source: https://github.com/jpd002/Play-
- Copyright: Jean-Philip Desjardins
- Licence text: `Play!/License.txt`
- Systems: PS2

### bsnes — GPL-3.0-only

- Upstream: https://github.com/libretro/bsnes
- Source: https://github.com/libretro/bsnes
- Copyright: byuu
- Licence text: `Libretro/bsnes/LICENSE.txt`
- Systems: Super Nintendo

### dolphin-ios — GPL-2.0-or-later

- Upstream: Dolphin
- Source: https://github.com/OatmealDome/dolphiniOS
- Copyright: Dolphin Emulator Project
- Licence text: `dolphin-ios/COPYING`
- Systems: GameCube, Wii

### genesis-plus-gx — LGPL-2.1-or-later

- Upstream: https://github.com/libretro/Genesis-Plus-GX
- Source: https://github.com/libretro/Genesis-Plus-GX
- Copyright: Charles MacDonald, Eke-Eke, Genesis Plus GX contributors
- Licence text: `Libretro/genesis-plus-gx/LICENSE.txt`
- Systems: Genesis, Master System, Game Gear, SG-1000

### iPSX2 — GPL-3.0-or-later

- Upstream: PCSX2
- Copyright: PCSX2 Dev Team
- Licence text: `iPSX2/iPSX2/COPYING.GPLv3`
- Systems: PS2

### mgba — MPL-2.0

- Upstream: https://github.com/libretro/mgba
- Source: https://github.com/libretro/mgba
- Copyright: Jeffrey Pfau, mGBA contributors, endrift
- Licence text: `Libretro/mgba/LICENSE`
- Systems: Game Boy, Game Boy Color, Game Boy Advance

### nestopia — GPL-2.0-or-later

- Upstream: https://github.com/libretro/nestopia
- Source: https://github.com/libretro/nestopia
- Copyright: Martin Freij, R. Belmont, Nestopia contributors
- Licence text: `Libretro/nestopia/COPYING`
- Systems: NES, Famicom

## Drawn from outside this repository

These are separate projects. Avalon uses work from them and the obligation to attribute it is the same as for anything in the tree.

### cemu-ios-muffin — MPL-2.0

- Source: https://github.com/kiddreads/cemu-ios-muffin
- Copyright: Cemu contributors, cemu-ios-muffin contributors
- Licence text: `cemu-ios-muffin/LICENSE.txt` (beside this repository)
- Used for: Touch control skins: the named-colour-token model and the twenty-two colour presets, re-expressed as Resources/controlskins.json. No muffin source code is present in Avalon.
- A sibling repository, not part of this one, so it resolves against the parent directory. Plain MPL-2.0: no file under src/ios/App carries the Exhibit B 'Incompatible With Secondary Licenses' notice, so MPL section 3.3 permits distribution under AGPL-3.0 as a Secondary License with the MPL files' own notices preserved. Further integration is on hold at the repository owner's request while work continues in that repo.

## Present in the repository but not in the build

- **iCube** — superseded by `dolphin-ios`.

## Components excluded for licence incompatibility

These are present in source projects but must not enter an Avalon build.

### Dolphin-derived CPU detection / ARM emitter — GPL-2.0-only

- Location: `PPSSPP/Common/CPUDetect.h (+9 more)` (in PPSSPP)
- Evidence: `PPSSPP/Common/CPUDetect.h:3-5 ('version 2.0.', no or-later); also ArmEmitter.{h,cpp}, ArmCPUDetect.cpp, RiscV/LoongArch/FakeCPUDetect.cpp, FakeEmitter.h, Core/ELF/PrxDecrypter.h`
- Reason: CPUDetect.h is included by 62 files including Common/Arm64Emitter.cpp — the exact code Avalon most wants to harvest. Rewrite CPU detection rather than inherit a v2-only obligation.

### Gambatte — GPL-2.0-only

- Location: `Folium/Kiwi/System` (in Folium)
- Evidence: `Folium/Kiwi/System/gambatte.cpp:4-6`
- Reason: INCOMPATIBLE with the GPL-3.0 umbrella Folium ships under. Must not enter Avalon.

### clown68000 — AGPL-3.0-or-later

- Location: `Folium/Plum/System/core/clown68000` (in Folium)
- Evidence: `Folium/Plum/System/core/clown68000/interpreter/clown68000.c:2-8`
- Reason: Stronger copyleft than its host; forces AGPL on any combined work.

### nonCommercialCores (PicoDrive, FBNeo, Snes9x) — NonCommercial

- Location: `Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Others/EmulationCore.swift` (in Manic EMU)
- Evidence: `Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Others/EmulationCore.swift:146-148`
- Reason: A no-commercial-use term is an additional restriction; GPL section 7 forbids it. These cores cannot be combined into a GPL/AGPL work.

### scrc32 (Genesis Plus GX libretro port) — NonCommercial

- Location: `Libretro/genesis-plus-gx/libretro/scrc32.h` (in genesis-plus-gx)
- Evidence: `Libretro/genesis-plus-gx/libretro/scrc32.h:9-13 ("Redistributions may not be sold, nor may they be used in a commercial product or activity.")`
- Reason: Non-commercial redistribution term; excluded from Avalon per GPL section 7 and the same reasoning that already excludes Snes9x and Manic EMU's gated cores. Confirmed dead code: nothing in AvalonLibretroGenesisPlusGX #includes it. crc32 is supplied by the system's zlib instead.

## Data excluded from redistribution

- `Folium/SharedDependencies/Sources/osa` — Embeds Nintendo 3DS system files (shared_font, mii, country_list) as C arrays. Copyrighted Nintendo data, not redistributable.


