This directory is a **build staging copy**, not a second vendored source of truth. It exists only
because SwiftPM resolves symlinks before checking that a target's default header path is "contained
in" the target — a real symlink to the canonical location fails that check even when nothing is
wrong. The canonical, attributed, git-history-preserving copy from the merge workflow is
`Libretro/genesis-plus-gx` at the repository root; this holds an exact copy of the subset of files
that subsystem's `AvalonLibretroGenesisPlusGX` target needs, refreshed from there, never edited here.

Genesis Plus GX is LGPL-2.1-or-later; see NOTICE.md and docs/ENGINEERING-MAP.md §5b.
