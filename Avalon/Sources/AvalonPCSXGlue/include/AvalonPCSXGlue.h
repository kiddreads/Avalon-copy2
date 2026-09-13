/* Avalon — the vtable connecting Avalon's frontend to pcsx_rearmed's namespaced core.
 * Mirrors AvalonGenesisPlusGXGlue.h / AvalonNestopiaGlue.h / AvalonMGBAGlue.h / AvalonBsnesGlue.h.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#ifndef AVALON_PCSX_GLUE_H
#define AVALON_PCSX_GLUE_H
#include "AvalonLibretro.h"
const avalon_libretro_vtable *avalon_pcsx_vtable(void);
#endif
