import Testing
import Foundation
@testable import AvalonCore

@Test("The bundled registry loads and covers every project in the repository")
func registryLoads() throws {
    let r = try ProjectRegistry.bundled()
    #expect(r.projects.count == 14)
    for id in ["Delta", "Fin", "Folium", "Manic EMU", "MeloNX",
               "PPSSPP", "Play!", "dolphin-ios", "iCube", "iPSX2",
               "genesis-plus-gx", "nestopia", "mgba", "bsnes"] {
        #expect(r.project(id) != nil, "missing \(id)")
    }
}

@Test("A naive licence audit that reads only project LICENSE files gets the wrong answer")
func vendoredCoresChangeTheAnswer() throws {
    let r = try ProjectRegistry.bundled()

    // Looking only at top-level licences suggests everything combines cleanly into AGPL.
    let naive = License.combinedLicense(of: r.projects.map(\.license))
    #expect(naive == .agpl3OrLater)

    // Including what is actually vendored inside those projects, it does not combine at all —
    // Gambatte (GPL-2.0-only) and Manic EMU's non-commercial cores each block it.
    #expect(r.combinedLicenseIfEverythingIncluded == nil)
}

@Test("Excluding the identified hazards yields a shippable AGPL-3.0 work")
func exclusionsMakeItShippable() throws {
    let r = try ProjectRegistry.bundled()
    // Hazard cores are excluded; no whole project needs dropping for licence reasons.
    let combined = r.combinedLicense(excluding: [])
    #expect(combined == .agpl3OrLater)
    #expect(combined?.hasNetworkClause == true)   // AGPL §13 covers the whole app
}

@Test("Every hazard carries file:line evidence, not an assertion")
func hazardsAreEvidenced() throws {
    let r = try ProjectRegistry.bundled()
    #expect(r.hazards.count >= 4)
    for h in r.hazards {
        #expect(!h.evidence.isEmpty, "\(h.name) has no evidence")
        #expect(h.evidence.contains(":") || h.evidence.contains("/"),
                "\(h.name) evidence is not a file reference: \(h.evidence)")
    }
    let names = Set(r.hazards.map(\.name))
    #expect(names.contains("Gambatte"))
}

@Test("Nintendo system data is recorded as excluded, not merely noted")
func excludedDataIsTracked() throws {
    let r = try ProjectRegistry.bundled()
    #expect(r.excludedData.contains { $0.path.contains("osa") })
    for e in r.excludedData { #expect(!e.reason.isEmpty) }
}

@Test("iCube is recorded as superseded by dolphin-ios")
func icubeIsMarkedSuperseded() throws {
    let r = try ProjectRegistry.bundled()
    let icube = try #require(r.project("iCube"))
    #expect(icube.supersededBy == "dolphin-ios")
    #expect(r.project("dolphin-ios")?.supersededBy == nil)
}

@Test("Play! is the only permissively licensed emulator, which is why it matters")
func playIsUniquelyPermissive() throws {
    let r = try ProjectRegistry.bundled()
    let permissive = r.projects.filter { !$0.license.requiresSourceDisclosure }
    #expect(permissive.map(\.id).sorted() == ["MeloNX", "Play!"])
    #expect(r.project("Play!")?.license == .bsd2Clause)
}

@Test("The generated notice names the licence, the hazards and the excluded data")
func noticeIsComplete() throws {
    let r = try ProjectRegistry.bundled()
    let n = r.generateNotice()
    #expect(n.contains("AGPL-3.0-or-later"))
    #expect(n.contains("§13"))                       // the network clause is stated, not implied
    #expect(n.contains("Jean-Philip Desjardins"))    // Play!'s BSD attribution requirement
    #expect(n.contains("Gambatte"))                  // excluded, and said so
    #expect(n.contains("osa"))                       // excluded Nintendo data
    #expect(n.contains("iCube"))                     // present but not built
    // Every included project must carry a licence path a reader can check.
    for p in r.projects where !p.isSuperseded {
        #expect(n.contains(p.licensePath), "notice omits licence path for \(p.id)")
    }
}
