/* A minimal but REAL libretro core, used to test Avalon's frontend against the actual ABI.
 *
 * Testing a frontend against a mock of itself proves nothing. This is a genuine core: it
 * implements every entry point libretro requires, negotiates a pixel format through the
 * environment callback, renders a frame that depends on its input state, produces audio, and
 * serializes. If Avalon's frontend is wrong, this fails.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#ifndef AVALON_LIBRETRO_TEST_CORE_H
#define AVALON_LIBRETRO_TEST_CORE_H
#include "AvalonLibretro.h"
/** Vtable for the test core, filled with its namespaced symbols. */
const avalon_libretro_vtable *avalon_test_core_vtable(void);
#endif
