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

@Suite("MPL-2.0 and external sources")
struct MPLLicenseTests {

    @Test("MPL-2.0 may be combined into an AGPL work")
    func mplCombinesWithAGPL() {
        // MPL §3.3: a covered file with no Exhibit B notice may be distributed under a Secondary
        // License, and AGPL-3.0 is one. The combined work is AGPL; the MPL files stay MPL.
        #expect(License.combinedLicense(of: [.mpl2, .agpl3OrLater]) == .agpl3OrLater)
        #expect(License.combinedLicense(of: [.mpl2, .gpl3OrLater]) == .gpl3OrLater)
        #expect(License.canCombine([.mpl2, .mit, .agpl3OrLater]))
    }

    @Test("MPL-2.0 is copyleft and still refuses a non-commercial term")
    func mplIsCopyleft() {
        #expect(License.mpl2.requiresSourceDisclosure)
        #expect(License.mpl2.permitsCommercialUse)
        #expect(!License.mpl2.hasNetworkClause)
        #expect(License.combinedLicense(of: [.mpl2, .nonCommercial]) == nil)
        #expect(License.combinedLicense(of: [.mpl2]) == .mpl2)
    }

    @Test("muffin is registered as an external source with its licence recorded")
    func muffinIsRegistered() throws {
        let registry = try ProjectRegistry.bundled()
        let muffin = try #require(registry.externalSources?.first { $0.id == "cemu-ios-muffin" })
        #expect(muffin.license == .mpl2)
        #expect(muffin.licensePath == "cemu-ios-muffin/LICENSE.txt")
        // It is NOT one of the ten projects in this repository, and must not be listed as one.
        #expect(registry.project("cemu-ios-muffin") == nil)
        // Its licence is counted when Avalon works out what a build may carry.
        #expect(registry.allLicensesInPlay.contains(.mpl2))
        #expect(registry.combinedLicense(excluding: ["Folium"]) != nil)
    }
}
