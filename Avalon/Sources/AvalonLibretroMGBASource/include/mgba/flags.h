/* Avalon — hand-resolved from src/core/flags.h.in.
 *
 * mGBA's real build generates this via CMake's configure_file, substituting each #cmakedefine
 * from feature detection and cache variables. There is no CMake here, so these are chosen
 * directly against what this platform (Darwin/iOS via SwiftPM) actually provides, rather than
 * detected. See docs/ENGINEERING-MAP.md for the reasoning behind each choice.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later (Avalon's own text, this file)
 * mGBA itself is MPL-2.0; see NOTICE.md.
 */
#ifndef FLAGS_H
#define FLAGS_H

/* MINIMAL_CORE gates video-logging/replay infrastructure (GBAVideoProxyRendererCreate and
   friends, in the deliberately-excluded extra/proxy.c) behind #ifndef in core.c -- exactly the
   debug/extra functionality this build has no use for and does not vendor. Confirmed by reading
   core.c directly, not assumed. */
#define MINIMAL_CORE 1

/* M_CORE: both systems this core actually hosts. */
#define M_CORE_GBA
#define M_CORE_GB

/* ENABLE: file-backed VFS only (no scripting, no GDB stub, no debuggers -- none of Avalon's
   cores expose those, and each is a real extra dependency surface to avoid without a reason). */
#define ENABLE_VFS
#define ENABLE_VFS_FILE
#define ENABLE_DIRECTORIES

/* USE: zlib is linked (AvalonLibretroGenesisPlusGX already established this is safe and
   permissively licensed); nothing else third-party is vendored, matching the same
   minimal-dependency choice already made for Genesis Plus GX's HAVE_CHD=0. */
#define USE_ZLIB

/* HAVE: capabilities Darwin's own libc genuinely provides. */
#define HAVE_CRC32
#define HAVE_STRDUP
#define HAVE_STRLCPY
#define HAVE_LOCALE
#define HAVE_LOCALTIME_R

/* Left undefined deliberately: BUILD_GL/GLES (no GPU renderer -- Avalon's contract is
   software-framebuffer, matching every other core so far), DISABLE_THREADING (left off: nothing
   here needs mGBA's own thread.c to no-op), MINIMAL_CORE, FIXED_ROM_BUFFER, COLOR_16_BIT/5_6_5
   (video-software.c picks its own internal format), everything USE_LIBZIP/USE_PNG/USE_FFMPEG/
   USE_LUA/USE_SQLITE3/USE_DISCORD_RPC/USE_EPOXY/USE_FREETYPE/USE_EDITLINE-shaped (no such
   dependency is vendored), ENABLE_SCRIPTING, ENABLE_GDB_STUB, ENABLE_DEBUGGERS. */

#endif
