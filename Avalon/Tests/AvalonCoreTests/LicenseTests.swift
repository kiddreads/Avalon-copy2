import Testing
@testable import AvalonCore

// These cases encode real findings from this repository, not invented examples.
// If a future change makes one of them fail, Avalon's redistribution story has broken.

@Test("The four top-level project licenses combine to AGPL-3.0")
func repositoryProjectsCombine() {
    // Play! (BSD), Dolphin family + PPSSPP (GPL-2.0-or-later),
    // Folium/iPSX2/MeloNX (GPL-3.0), Delta/Manic EMU (AGPL-3.0).
    let present: [License] = [.bsd3Clause, .gpl2OrLater, .gpl3OrLater, .agpl3OrLater]
    #expect(License.combinedLicense(of: present) == .agpl3OrLater)
}

@Test("Gambatte's GPL-2.0-only blocks combination with any v3 license")
func gambatteBlocksV3() {
    // Folium/Kiwi/System/gambatte.cpp:4-6 — "version 2", no "or later".
    #expect(License.combinedLicense(of: [.gpl2Only, .gpl3OrLater]) == nil)
    #expect(License.combinedLicense(of: [.gpl2Only, .agpl3OrLater]) == nil)
    // ...which means Folium itself, shipping GPL-3.0, already has this problem.
    #expect(License.canCombine([.gpl2Only, .gpl3OrLater]) == false)
}

@Test("GPL-2.0-only still combines with v2-or-later and permissive code")
func gambatteCombinesDownward() {
    #expect(License.combinedLicense(of: [.gpl2Only, .gpl2OrLater]) == .gpl2Only)
    #expect(License.combinedLicense(of: [.gpl2Only, .bsd3Clause]) == .gpl2Only)
}

@Test("or-later grants are what make the rest of the repository combinable")
func orLaterIsLoadBearing() {
    // Dolphin: SPDX-License-Identifier: GPL-2.0-or-later (Source/Core/Core/Core.cpp:2)
    // PPSSPP:  "version 2.0 or later versions"        (Core/Core.cpp:5)
    #expect(License.combinedLicense(of: [.gpl2OrLater, .agpl3OrLater]) == .agpl3OrLater)
}

@Test("Only AGPL carries the network clause")
func networkClause() {
    #expect(License.agpl3OrLater.hasNetworkClause)
    #expect(!License.gpl3OrLater.hasNetworkClause)
    #expect(License.bsd3Clause.requiresSourceDisclosure == false)
}

@Test("Play! being permissive is what makes it uniquely reusable")
func permissiveAbsorbs() {
    #expect(License.combinedLicense(of: [.bsd3Clause]) == .bsd3Clause)
    #expect(License.combinedLicense(of: []) == nil)
}
