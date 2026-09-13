/* Copyright (c) 2013-2016 Jeffrey Pfau
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#include <mgba/core/version.h>

/* Avalon — hand-resolved from src/core/version.c.in (normally CMake-substituted from git
   metadata this checkout does not have, since it is a subtree grafted by the merge workflow,
   not mGBA's own git history). SPDX-License-Identifier for this substitution: AGPL-3.0-or-later. */
MGBA_EXPORT const char* const gitCommit = "unknown";
MGBA_EXPORT const char* const gitCommitShort = "unknown";
MGBA_EXPORT const char* const gitBranch = "unknown";
MGBA_EXPORT const int gitRevision = 0;
MGBA_EXPORT const char* const binaryName = "mgba";
MGBA_EXPORT const char* const projectName = "mGBA";
MGBA_EXPORT const char* const projectVersion = "0.10-avalon";
