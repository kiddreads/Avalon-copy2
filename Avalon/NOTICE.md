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

### dolphin-ios — GPL-2.0-or-later

- Upstream: Dolphin
- Source: https://github.com/OatmealDome/dolphiniOS
- Copyright: Dolphin Emulator Project
- Licence text: `dolphin-ios/COPYING`
- Systems: GameCube, Wii

### iPSX2 — GPL-3.0-or-later

- Upstream: PCSX2
- Copyright: PCSX2 Dev Team
- Licence text: `iPSX2/iPSX2/COPYING.GPLv3`
- Systems: PS2

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

- Location: `Manic EMU/.../EmulationCore.swift:146-148` (in Manic EMU)
- Evidence: `Manic EMU/Manic EMU/ManicEmu/Sources/Tools/Others/EmulationCore.swift:146-148`
- Reason: A no-commercial-use term is an additional restriction; GPL section 7 forbids it. These cores cannot be combined into a GPL/AGPL work.

## Data excluded from redistribution

- `Folium/SharedDependencies/Sources/osa` — Embeds Nintendo 3DS system files (shared_font, mii, country_list) as C arrays. Copyrighted Nintendo data, not redistributable.

