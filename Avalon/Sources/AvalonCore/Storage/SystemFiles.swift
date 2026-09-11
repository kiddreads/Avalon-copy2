// Avalon — required system files.
//
// Most emulated systems need files Avalon cannot ship: a BIOS dump, keys, firmware. Folium is the
// only project here that models this declaratively, with a per-system required/optional table and a
// gate before launch (`Folium/.../Actors/DirectoryManager.swift:20-170`, gate in
// `GamesController.swift:564+`). Everything else discovers the problem by failing to boot.
//
// It also records something that matters for choosing between cores: Play! needs **no** PS2 BIOS
// because it high-level-emulates the kernel (`Play!/Source/ee/PS2OS.cpp`,
// `Play!/Source/iop/IopBios.cpp`), while PCSX2/iPSX2 requires a dump. Same console, very different
// thing to ask of a user. `CoreCandidate` below makes that difference visible when picking a core.
//
// Avalon never ships these files and never fetches them. It reports what is missing.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

public struct SystemFileRequirement: Hashable, Sendable, Codable {
    public enum Necessity: String, Sendable, Codable { case required, optional }

    /// Filename Avalon looks for, e.g. `"bios7.bin"`.
    public let filename: String
    public let necessity: Necessity
    /// What it is, for a message the user can act on.
    public let purpose: String
    /// Exact size in bytes, when known — the cheapest way to catch a wrong file.
    public let expectedSize: Int?
    /// Lowercase hex SHA-1 of a known-good dump, when known.
    public let sha1: String?

    public init(filename: String, necessity: Necessity, purpose: String,
                expectedSize: Int? = nil, sha1: String? = nil) {
        self.filename = filename; self.necessity = necessity; self.purpose = purpose
        self.expectedSize = expectedSize; self.sha1 = sha1
    }
}

public enum SystemFileStatus: Equatable, Sendable {
    case present
    case missing
    /// Present but the wrong size — almost always a truncated or misnamed file.
    case wrongSize(expected: Int, found: Int)

    public var isUsable: Bool { self == .present }
}

public struct SystemFileReport: Sendable {
    public let statuses: [String: SystemFileStatus]
    public let requirements: [SystemFileRequirement]

    /// Whether the core can start at all.
    public var canLaunch: Bool {
        requirements.filter { $0.necessity == .required }
            .allSatisfy { statuses[$0.filename]?.isUsable == true }
    }

    public var missingRequired: [SystemFileRequirement] {
        requirements.filter { $0.necessity == .required && statuses[$0.filename]?.isUsable != true }
    }

    public var missingOptional: [SystemFileRequirement] {
        requirements.filter { $0.necessity == .optional && statuses[$0.filename]?.isUsable != true }
    }

    /// A message that tells the user what to do, naming files rather than saying "BIOS missing".
    public var userFacingSummary: String {
        guard !canLaunch else {
            let opt = missingOptional
            return opt.isEmpty ? "All system files present."
                : "Ready. Optional files not found: " + opt.map(\.filename).joined(separator: ", ")
        }
        return "Cannot start. Missing required files:\n" + missingRequired.map {
            var line = "  • \($0.filename) — \($0.purpose)"
            if case .wrongSize(let e, let f) = statuses[$0.filename] {
                line += " (found \(f) bytes, expected \(e))"
            }
            return line
        }.joined(separator: "\n")
    }
}

/// Checks a directory against a core's declared requirements.
public struct SystemFileChecker: Sendable {
    public init() {}

    // FileManager is not Sendable, so it is used per call rather than stored — otherwise this
    // struct could not cross an actor boundary, which is exactly where a launch gate runs.
    public func check(_ requirements: [SystemFileRequirement], in directory: URL,
                      using fileManager: FileManager = .default) -> SystemFileReport {
        var statuses: [String: SystemFileStatus] = [:]
        for req in requirements {
            let url = directory.appendingPathComponent(req.filename)
            guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int else {
                statuses[req.filename] = .missing
                continue
            }
            if let expected = req.expectedSize, expected != size {
                statuses[req.filename] = .wrongSize(expected: expected, found: size)
            } else {
                statuses[req.filename] = .present
            }
        }
        return SystemFileReport(statuses: statuses, requirements: requirements)
    }
}

/// A core Avalon could use for a system, and what it costs the user to do so.
///
/// Exists so that "which PS2 core?" is answerable on the evidence rather than by preference: one
/// needs a BIOS dump the user may not have, the other does not.
public struct CoreCandidate: Sendable {
    public let descriptor: CoreDescriptor
    public let systemFiles: [SystemFileRequirement]

    public init(descriptor: CoreDescriptor, systemFiles: [SystemFileRequirement] = []) {
        self.descriptor = descriptor; self.systemFiles = systemFiles
    }

    public var requiresUserSuppliedFiles: Bool {
        systemFiles.contains { $0.necessity == .required }
    }

    /// Rank candidates for a system: cores needing nothing from the user come first, then those
    /// that can use JIT, then by name for determinism.
    public static func preferred(from candidates: [CoreCandidate],
                                 jitAvailable: Bool) -> CoreCandidate? {
        candidates.min { a, b in
            if a.requiresUserSuppliedFiles != b.requiresUserSuppliedFiles {
                return !a.requiresUserSuppliedFiles
            }
            let aJIT = a.descriptor.capabilities.contains(.requiresJIT)
            let bJIT = b.descriptor.capabilities.contains(.requiresJIT)
            if !jitAvailable, aJIT != bJIT { return !aJIT }
            return a.descriptor.id < b.descriptor.id
        }
    }
}
