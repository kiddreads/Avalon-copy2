/*
 * Avalon — executable memory.
 *
 * Adapted from the two most complete treatments in this repository:
 *
 *   • iPSX2's four-mode strategy (iPSX2/iPSX2/cpp/common/Darwin/DarwinMisc.cpp:645-860):
 *     simulator / TXM / non-TXM / legacy, MAP_JIT with an mprotect fallback, and the
 *     `g_code_rw_offset` idea of threading a write-offset through the emitters so a dual mapping
 *     needs no change at each write site (common/emitter/x86emitter.cpp:102-105).
 *   • MeloNX's dual RW/RX aliasing via vm_remap
 *     (MeloNX/src/Ryujinx.Memory/DualMappedJitAllocator.cs:85-105): write through one address,
 *     execute through another, never reprotect.
 *
 * What is Avalon's rather than inherited: this is a *service*, not a per-core facility. Cores never
 * probe, map or detach; they receive a region. That exists because MeloNX permanently closes the
 * process's ability to map executable memory after reserving its cache, so an unarbitrated second
 * core silently loses its JIT.
 *
 * Deliberately not copied line-for-line from iPSX2, which is GPL-3.0: the technique is
 * re-implemented from the public Apple APIs so Avalon's licence position stays its own.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifndef AVALON_JIT_H
#define AVALON_JIT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    AVALON_JIT_UNAVAILABLE     = 0,
    AVALON_JIT_SIMULATOR       = 1, /* plain RWX */
    AVALON_JIT_MAPJIT          = 2, /* MAP_JIT + pthread_jit_write_protect_np */
    AVALON_JIT_DUALMAP         = 3, /* vm_remap RW alias over an RX region */
    AVALON_JIT_PROTECT_TOGGLE  = 4  /* mprotect RW<->RX; forbids concurrent codegen */
} avalon_jit_mode;

/* One allocated region of executable memory. */
typedef struct {
    void *rx;               /* execute through this address */
    void *rw;               /* write through this address; == rx except in DUALMAP */
    size_t size;
    avalon_jit_mode mode;
    int writable;           /* tracks begin_write/end_write nesting state */
} avalon_jit_region;

/* Best mode actually usable in this process, probed rather than assumed. */
avalon_jit_mode avalon_jit_detect(void);

const char *avalon_jit_mode_name(avalon_jit_mode mode);

/* Non-zero if the mode permits one thread compiling while another executes. */
int avalon_jit_mode_allows_concurrent_codegen(avalon_jit_mode mode);

/* Allocate. `mode` may be AVALON_JIT_UNAVAILABLE to mean "detect". Returns 0 on success. */
int avalon_jit_alloc(avalon_jit_region *out, size_t size, avalon_jit_mode mode);

void avalon_jit_free(avalon_jit_region *region);

/*
 * Offset from an execute address to its writable alias.
 *
 * This is iPSX2's g_code_rw_offset idea: an emitter that computes addresses in the RX space can
 * write at `addr + offset` without knowing which mode is in force. Zero for every mode but DUALMAP.
 */
ptrdiff_t avalon_jit_rw_offset(const avalon_jit_region *region);

/*
 * Open the region for writing, and close it again.
 *
 * For MAP_JIT this toggles the thread's write protection; for PROTECT_TOGGLE it calls mprotect;
 * for DUALMAP and SIMULATOR both are no-ops, which is exactly why those modes are faster.
 * end_write also invalidates the instruction cache for the range.
 *
 * Note these are NOT nestable — the same limitation PPSSPP documents at Common/CodeBlock.h:105.
 * Returns 0 on success.
 */
int avalon_jit_begin_write(avalon_jit_region *region);
int avalon_jit_end_write(avalon_jit_region *region);

/* Invalidate icache for a sub-range after writing it. */
void avalon_jit_flush_icache(const void *addr, size_t size);

/** Whether this platform has a per-thread W^X toggle (`pthread_jit_write_protect_np`).
 *
 *  True on macOS, false on iOS and everywhere else. `AVALON_JIT_MAPJIT` is only usable where this
 *  is true, which is why `avalon_jit_detect()` will not return it on iOS. */
int avalon_jit_has_wx_toggle(void);

#ifdef __cplusplus
}
#endif
#endif /* AVALON_JIT_H */
