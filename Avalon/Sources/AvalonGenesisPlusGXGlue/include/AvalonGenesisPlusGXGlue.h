/* Avalon — the vtable that connects Avalon's frontend to Genesis Plus GX's namespaced core.
 *
 * This file is deliberately separate from AvalonLibretroGenesisPlusGX (the core's own compiled
 * source). That target avoids Clang modules entirely, on purpose: modules cache a header's
 * declarations under the macro environment active when the module was first built, which breaks
 * the textual `#define retro_init gpgx_retro_init` renaming genesisplusgx_namespace.h relies on.
 * This file has no such requirement -- it only needs `avalon_libretro_vtable`'s definition and
 * plain `extern` prototypes for the already-renamed `gpgx_retro_*` symbols -- so it is free to
 * depend on AvalonLibretro normally.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#ifndef AVALON_GENESISPLUSGX_GLUE_H
#define AVALON_GENESISPLUSGX_GLUE_H
#include "AvalonLibretro.h"
const avalon_libretro_vtable *avalon_genesisplusgx_vtable(void);
#endif
