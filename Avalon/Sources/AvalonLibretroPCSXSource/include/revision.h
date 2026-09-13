/* Hand-resolved: upstream's Makefile generates this via `git describe` at build time
 * (`include/revision.h: FORCE` -> `#define REV "<git describe output>"`). Avalon's build has no
 * equivalent VCS-describe step for a vendored, namespaced core, so this is a fixed string rather
 * than a generated one -- matching the precedent set for mGBA's own hand-resolved flags.h/version.c.
 */
#define REV "avalon"
