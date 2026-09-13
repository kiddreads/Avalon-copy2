import Testing
import Foundation
@testable import AvalonCore

private func tempDir() throws -> URL {
    let d = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avalon-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}
private func write(_ dir: URL, _ name: String, bytes: Int) throws {
    try Data(repeating: 0, count: bytes).write(to: dir.appendingPathComponent(name))
}

// Real PS2 requirements. PCSX2 needs a BIOS dump; Play! does not, because it HLEs the kernel.
private let pcsx2Files = [
    SystemFileRequirement(filename: "SCPH-70012.bin", necessity: .required,
                          purpose: "PS2 BIOS image", expectedSize: 4_194_304),
]
private let playFiles: [SystemFileRequirement] = []

private func ps2Core(_ id: String, requiresJIT: Bool, files: Bool) -> CoreCandidate {
    CoreCandidate(
        descriptor: CoreDescriptor(
            id: id, displayName: id, version: "1", system: .playStation2,
            screens: [ScreenDescriptor(id: "main", nativeSize: .init(width: 640, height: 448))],
            renderingModel: .nativeSurface(api: .metal), frameDuration: 1.0/59.94,
            capabilities: requiresJIT ? [.requiresJIT] : [.jitOptional]),
        systemFiles: files ? pcsx2Files : playFiles)
}

@Test("A missing BIOS blocks launch and says which file")
func missingRequiredBlocks() throws {
    let d = try tempDir(); defer { try? FileManager.default.removeItem(at: d) }
    let report = SystemFileChecker().check(pcsx2Files, in: d)
    #expect(report.canLaunch == false)
    #expect(report.missingRequired.count == 1)
    #expect(report.userFacingSummary.contains("SCPH-70012.bin"))
    #expect(report.userFacingSummary.contains("PS2 BIOS image"))
}

@Test("A truncated BIOS is caught by size, not by a boot failure later")
func wrongSizeIsCaught() throws {
    let d = try tempDir(); defer { try? FileManager.default.removeItem(at: d) }
    try write(d, "SCPH-70012.bin", bytes: 1024)          // truncated download
    let report = SystemFileChecker().check(pcsx2Files, in: d)
    #expect(report.canLaunch == false)
    #expect(report.statuses["SCPH-70012.bin"] == .wrongSize(expected: 4_194_304, found: 1024))
    #expect(report.userFacingSummary.contains("found 1024 bytes"))
}

@Test("A correct BIOS permits launch")
func correctFilePasses() throws {
    let d = try tempDir(); defer { try? FileManager.default.removeItem(at: d) }
    try write(d, "SCPH-70012.bin", bytes: 4_194_304)
    let report = SystemFileChecker().check(pcsx2Files, in: d)
    #expect(report.canLaunch)
    #expect(report.userFacingSummary.contains("All system files present"))
}

@Test("Optional files are reported but never block")
func optionalDoesNotBlock() throws {
    let d = try tempDir(); defer { try? FileManager.default.removeItem(at: d) }
    let reqs = [SystemFileRequirement(filename: "nand.bin", necessity: .optional,
                                      purpose: "Wii NAND backup")]
    let report = SystemFileChecker().check(reqs, in: d)
    #expect(report.canLaunch)
    #expect(report.missingOptional.count == 1)
    #expect(report.userFacingSummary.contains("nand.bin"))
}

@Test("Core selection prefers the PS2 core that needs nothing from the user")
func playIsPreferredOverPcsx2() {
    // The concrete payoff of the reconnaissance: Play! HLEs the PS2 kernel, so it needs no BIOS
    // dump, while iPSX2 requires one. Given both, Avalon picks the one the user can actually run.
    let candidates = [ps2Core("ipsx2", requiresJIT: true, files: true),
                      ps2Core("play", requiresJIT: false, files: false)]
    let chosen = CoreCandidate.preferred(from: candidates, jitAvailable: true)
    #expect(chosen?.descriptor.id == "play")
    #expect(chosen?.requiresUserSuppliedFiles == false)
}

@Test("With no JIT, a core that demands JIT loses to one that does not")
func jitAvailabilityAffectsSelection() {
    let candidates = [ps2Core("needsJIT", requiresJIT: true, files: false),
                      ps2Core("interpreted", requiresJIT: false, files: false)]
    #expect(CoreCandidate.preferred(from: candidates, jitAvailable: false)?.descriptor.id == "interpreted")
    // With JIT available the tie breaks deterministically by id rather than arbitrarily.
    #expect(CoreCandidate.preferred(from: candidates, jitAvailable: true)?.descriptor.id == "interpreted")
}

@Suite("System catalog")
struct SystemCatalogTests {

    @Test("every system maps to a control layout that exists")
    func layoutsResolve() throws {
        let layouts = try TouchLayoutLibrary.builtIn()
        for profile in SystemCatalog.all {
            #expect(layouts.layout(id: profile.layoutID) != nil,
                    "\(profile.shortName) wants layout '\(profile.layoutID)', which does not exist")
        }
    }

    @Test("extensions resolve, and ambiguous ones return every candidate")
    func extensions() {
        #expect(SystemCatalog.profiles(forExtension: "nes").first?.id == .nes)
        #expect(SystemCatalog.profiles(forExtension: ".Z64").first?.id == .nintendo64)
        #expect(SystemCatalog.profiles(forExtension: "ch8").first?.coreStatus.isAvailable == true)
        #expect(SystemCatalog.profiles(forExtension: "xyz").isEmpty)
        #expect(SystemCatalog.profiles(forExtension: "").isEmpty)

        // An .iso is three different consoles and the player has to be the one to say which.
        let iso = SystemCatalog.profiles(forExtension: "iso").map(\.id)
        #expect(iso.count == 3)
        #expect(iso.contains(.gameCube) && iso.contains(.playStation2) && iso.contains(.psp))
    }

    @Test("every playable system genuinely has a core wired to it")
    func honestAboutCores() {
        // Grows as real cores land; the point is never "looks like N systems work" without each
        // one actually resolving to a core that runs, which is what LibretroCoreTests and
        // GenesisPlusGXCoreTests independently prove for their respective entries.
        #expect(SystemCatalog.playable.count == 6)
        #expect(Set(SystemCatalog.playable.map(\.id)) ==
                [.chip8, .genesis, .nes, .gameBoy, .gameBoyAdvance, .snes])
        // Every system without a core has to say what it is waiting for.
        for profile in SystemCatalog.all where !profile.coreStatus.isAvailable {
            guard case .notYet(let note) = profile.coreStatus else { continue }
            #expect(note.count > 20, "\(profile.shortName): the reason is not specific enough")
        }
    }

    @Test("no two systems claim the same unambiguous extension")
    func noSilentCollisions() {
        var owner: [String: String] = [:]
        for profile in SystemCatalog.all {
            for ext in profile.fileExtensions {
                if let existing = owner[ext] {
                    // Collisions are allowed only where the catalog declares them ambiguous.
                    #expect(SystemCatalog.profiles(forExtension: ext).count > 1,
                            "\(ext) is claimed by both \(existing) and \(profile.shortName) with no ordering")
                }
                owner[ext] = profile.shortName
            }
        }
    }
}
