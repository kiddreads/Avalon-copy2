/* Avalon — the vtable connecting Avalon's frontend to Nestopia's namespaced core.
 * Mirrors AvalonGenesisPlusGXGlue.h; see that file for why this is a separate target.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#ifndef AVALON_NESTOPIA_GLUE_H
#define AVALON_NESTOPIA_GLUE_H
#include "AvalonLibretro.h"
const avalon_libretro_vtable *avalon_nestopia_vtable(void);
#endif
