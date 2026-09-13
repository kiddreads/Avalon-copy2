/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonJIT.h"

#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <pthread.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>

/* `pthread_jit_write_protect_np` is macOS-only. Apple declares it in the shared Darwin headers
   and marks it unavailable on iOS, so a package that has only ever been built for macOS compiles
   clean and still cannot be built for the platform it claims to support. This one did, until CI
   compiled it against the iOS SDK for the first time.

   The consequence is bigger than a guard. On iOS there is no per-thread W^X toggle at all: a
   MAP_JIT region comes back executable and stays that way, so selecting MAP_JIT there would
   produce a region nothing can write to. Dual mapping through `vm_remap` is the whole strategy on
   iOS, which is exactly the ladder DolphiniOS settled on
   (`dolphin-ios/Source/Core/Common/MemoryUtil_iOS.cpp`). */
#if TARGET_OS_OSX
#define AVALON_JIT_HAS_WX_TOGGLE 1
#else
#define AVALON_JIT_HAS_WX_TOGGLE 0
#endif
#else
#define AVALON_JIT_HAS_WX_TOGGLE 0
#endif

const char *avalon_jit_mode_name(avalon_jit_mode mode) {
    switch (mode) {
        case AVALON_JIT_UNAVAILABLE:    return "unavailable";
        case AVALON_JIT_SIMULATOR:      return "simulator";
        case AVALON_JIT_MAPJIT:         return "mapJIT";
        case AVALON_JIT_DUALMAP:        return "dualMapped";
        case AVALON_JIT_PROTECT_TOGGLE: return "protectToggle";
    }
    return "unknown";
}

int avalon_jit_mode_allows_concurrent_codegen(avalon_jit_mode mode) {
    /* protectToggle changes protection for the whole region, so a second thread executing from it
       during a write would fault. This is the constraint that makes PPSSPP's codegen single
       threaded, and it must be reported honestly rather than assumed away. */
    return mode == AVALON_JIT_SIMULATOR || mode == AVALON_JIT_MAPJIT || mode == AVALON_JIT_DUALMAP;
}

int avalon_jit_has_wx_toggle(void) { return AVALON_JIT_HAS_WX_TOGGLE; }

void avalon_jit_flush_icache(const void *addr, size_t size) {
#if defined(__APPLE__)
    sys_icache_invalidate((void *)addr, size);
#elif defined(__GNUC__)
    __builtin___clear_cache((char *)addr, (char *)addr + size);
#else
    (void)addr; (void)size;
#endif
}

static size_t page_round(size_t n) {
    long ps = sysconf(_SC_PAGESIZE);
    if (ps <= 0) ps = 16384;
    size_t p = (size_t)ps;
    return (n + p - 1) & ~(p - 1);
}

/* --- probing ------------------------------------------------------------ */

#if defined(__APPLE__)
static int probe_mapjit(void) {
    size_t sz = page_round(1);
    void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE | PROT_EXEC,
                   MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0);
    if (p == MAP_FAILED) return 0;
    munmap(p, sz);
    return 1;
}

/* The Simulator runs as an ordinary macOS process, where a single combined RWX mapping usually
   just works with no MAP_JIT and no entitlement at all -- until it doesn't. A test-hosted
   process (`xcodebuild test` against the iOS Simulator) failed exactly this mmap in CI with
   `.unavailable(reason: "could not map ... bytes as simulator")`, while the very same run's
   MAP_JIT/dual-map tests, exercised as a plain macOS process on the same machine, passed. That
   points at the test host's own sandboxing, not the CPU or the OS release, so it has to be
   probed rather than assumed: nothing here can distinguish "Simulator app I ran manually" from
   "Simulator process xctest is driving" except by trying the mapping. */
static int probe_simulator_combined(void) {
    size_t sz = page_round(1);
    void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (p == MAP_FAILED) return 0;
    munmap(p, sz);
    return 1;
}

static int probe_dualmap(void) {
    size_t sz = page_round(1);
    void *rx = mmap(NULL, sz, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (rx == MAP_FAILED) return 0;
    vm_address_t rw = 0;
    vm_prot_t cur = 0, max = 0;
    kern_return_t kr = vm_remap(mach_task_self(), &rw, sz, 0, VM_FLAGS_ANYWHERE,
                                mach_task_self(), (vm_address_t)rx, FALSE, &cur, &max,
                                VM_INHERIT_NONE);
    if (kr != KERN_SUCCESS) { munmap(rx, sz); return 0; }
    vm_deallocate(mach_task_self(), rw, sz);
    munmap(rx, sz);
    return 1;
}
#endif

avalon_jit_mode avalon_jit_detect(void) {
#if defined(__APPLE__)
#if TARGET_OS_SIMULATOR
    /* Probed, not assumed -- see probe_simulator_combined(). Dual mapping is the fallback because
       it is already proven to work on this same kind of process (real iOS devices have no other
       option), and it asks for nothing a combined RWX page needs that a sandboxed host might
       refuse. */
    if (probe_simulator_combined()) return AVALON_JIT_SIMULATOR;
    if (probe_dualmap()) return AVALON_JIT_DUALMAP;
    return AVALON_JIT_UNAVAILABLE;
#elif AVALON_JIT_HAS_WX_TOGGLE
    /* macOS. Preference order is by cost, not by novelty. MAP_JIT is the cheapest correct option
       on modern Apple silicon; dual mapping costs an extra VA mapping but never reprotects, which
       matters when a second core is executing while this one compiles. */
    if (probe_mapjit()) return AVALON_JIT_MAPJIT;
    if (probe_dualmap()) return AVALON_JIT_DUALMAP;
    return AVALON_JIT_UNAVAILABLE;
#else
    /* iOS and its relatives. MAP_JIT is deliberately NOT offered here even though the mmap
       succeeds: without a W^X toggle the region can never be made writable, so choosing it would
       hand back a region that faults on the first store. Dual mapping is the only mode that
       works, and if the process cannot get it, JIT is honestly unavailable rather than broken. */
    if (probe_dualmap()) return AVALON_JIT_DUALMAP;
    return AVALON_JIT_UNAVAILABLE;
#endif
#else
    return AVALON_JIT_PROTECT_TOGGLE;
#endif
}

/* --- allocation --------------------------------------------------------- */

int avalon_jit_alloc(avalon_jit_region *out, size_t size, avalon_jit_mode mode) {
    if (!out || size == 0) return -1;
    memset(out, 0, sizeof *out);
    if (mode == AVALON_JIT_UNAVAILABLE) mode = avalon_jit_detect();
    if (mode == AVALON_JIT_UNAVAILABLE) return -1;

    size_t sz = page_round(size);

#if defined(__APPLE__)
    if (mode == AVALON_JIT_MAPJIT) {
        void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE | PROT_EXEC,
                       MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0);
        if (p == MAP_FAILED) return -1;
        out->rx = out->rw = p;
    } else if (mode == AVALON_JIT_DUALMAP) {
        void *rx = mmap(NULL, sz, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
        if (rx == MAP_FAILED) return -1;
        vm_address_t rw = 0;
        vm_prot_t cur = 0, max = 0;
        kern_return_t kr = vm_remap(mach_task_self(), &rw, sz, 0, VM_FLAGS_ANYWHERE,
                                    mach_task_self(), (vm_address_t)rx, FALSE, &cur, &max,
                                    VM_INHERIT_NONE);
        if (kr != KERN_SUCCESS) { munmap(rx, sz); return -1; }
        if (vm_protect(mach_task_self(), rw, sz, FALSE,
                       VM_PROT_READ | VM_PROT_WRITE) != KERN_SUCCESS) {
            vm_deallocate(mach_task_self(), rw, sz); munmap(rx, sz); return -1;
        }
        out->rx = rx;
        out->rw = (void *)rw;
    } else
#endif
    if (mode == AVALON_JIT_SIMULATOR) {
        void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE | PROT_EXEC,
                       MAP_PRIVATE | MAP_ANON, -1, 0);
        if (p == MAP_FAILED) return -1;
        out->rx = out->rw = p;
    } else if (mode == AVALON_JIT_PROTECT_TOGGLE) {
        void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
        if (p == MAP_FAILED) return -1;
        out->rx = out->rw = p;
    } else {
        return -1;
    }

    out->size = sz;
    out->mode = mode;
    out->writable = (mode == AVALON_JIT_DUALMAP || mode == AVALON_JIT_SIMULATOR);
    return 0;
}

void avalon_jit_free(avalon_jit_region *region) {
    if (!region || !region->rx) return;
#if defined(__APPLE__)
    if (region->mode == AVALON_JIT_DUALMAP && region->rw && region->rw != region->rx) {
        vm_deallocate(mach_task_self(), (vm_address_t)region->rw, region->size);
    }
#endif
    munmap(region->rx, region->size);
    memset(region, 0, sizeof *region);
}

ptrdiff_t avalon_jit_rw_offset(const avalon_jit_region *region) {
    if (!region || !region->rw || !region->rx) return 0;
    return (ptrdiff_t)((char *)region->rw - (char *)region->rx);
}

int avalon_jit_begin_write(avalon_jit_region *region) {
    if (!region || !region->rx) return -1;
    switch (region->mode) {
        case AVALON_JIT_MAPJIT:
#if AVALON_JIT_HAS_WX_TOGGLE
            pthread_jit_write_protect_np(0);
            region->writable = 1;
            return 0;
#else
            /* Refuse rather than lie. A caller told "writable" that then faults on its first
               store is far worse than one told it cannot have this mode here. */
            return -1;
#endif
        case AVALON_JIT_PROTECT_TOGGLE:
            if (mprotect(region->rx, region->size, PROT_READ | PROT_WRITE) != 0) return -1;
            region->writable = 1;
            return 0;
        case AVALON_JIT_DUALMAP:
        case AVALON_JIT_SIMULATOR:
            return 0;   /* already writable through rw; nothing to pay */
        default:
            return -1;
    }
}

int avalon_jit_end_write(avalon_jit_region *region) {
    if (!region || !region->rx) return -1;
    switch (region->mode) {
        case AVALON_JIT_MAPJIT:
#if AVALON_JIT_HAS_WX_TOGGLE
            pthread_jit_write_protect_np(1);
            region->writable = 0;
            break;
#else
            return -1;
#endif
        case AVALON_JIT_PROTECT_TOGGLE:
            if (mprotect(region->rx, region->size, PROT_READ | PROT_EXEC) != 0) return -1;
            region->writable = 0;
            break;
        default:
            break;
    }
    avalon_jit_flush_icache(region->rx, region->size);
    return 0;
}
