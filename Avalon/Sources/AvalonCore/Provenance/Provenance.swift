// Avalon — provenance record for imported and adapted code.
//
// Every component Avalon takes from a source project carries one of these. The point is that
// attribution and license obligations stay attached to the code as it is refactored, rather than
// living in a NOTICE file that drifts out of date the first time something moves.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// How far a component has actually travelled from its source project.
///
/// The brief for this work is explicit that "files were copied" is not integration. These cases are
/// that distinction made machine-readable, so `INTEGRATION-STATUS.md` can be generated from the code
/// rather than written by hand and quietly allowed to lie.
public enum IntegrationStage: String, Codable, Sendable, CaseIterable, Comparable {
    /// Found in the repository; nothing read in depth yet.
    case discovered
    /// Implementation read and understood; strengths and coupling documented.
    case analyzed
    /// Chosen as the implementation Avalon will use for its subsystem.
    case selected
    /// Rewritten against Avalon's interfaces; not yet wired into a running path.
    case adapted
    /// Wired in, but some functionality still routes through the original project.
    case partiallyIntegrated
    /// Avalon uses it, through Avalon's interfaces, with no dependency on its original host.
    case integrated
    /// Covered by tests that actually exercise it.
    case tested
    /// Verified behaving correctly in a running Avalon build.
    case validated

    private var order: Int {
        switch self {
        case .discovered: return 0
        case .analyzed: return 1
        case .selected: return 2
        case .adapted: return 3
        case .partiallyIntegrated: return 4
        case .integrated: return 5
        case .tested: return 6
        case .validated: return 7
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }

    /// Whether this stage may honestly be described as "in Avalon" in user-facing material.
    public var isInAvalon: Bool { self >= .integrated }
}

/// A project this repository contains and Avalon may draw from.
public struct SourceProject: Codable, Sendable, Identifiable, Hashable {
    /// Directory name at the repository root, e.g. `"Manic EMU"`.
    public let id: String
    /// Upstream project this is a fork or port of, if any.
    public let upstream: String?
    public let origin: URL?
    public let license: License
    /// Where the license text lives, repo-relative. Kept so attribution can be verified, not assumed.
    public let licensePath: String
    public let copyrightHolders: [String]
    /// Systems emulated, for the capability matrix.
    public let systems: [String]

    public init(id: String, upstream: String? = nil, origin: URL? = nil, license: License,
                licensePath: String, copyrightHolders: [String] = [], systems: [String] = []) {
        self.id = id; self.upstream = upstream; self.origin = origin
        self.license = license; self.licensePath = licensePath
        self.copyrightHolders = copyrightHolders; self.systems = systems
    }
}

/// One Avalon component and where it came from.
public struct ComponentProvenance: Codable, Sendable, Identifiable, Hashable {
    /// Avalon subsystem path, e.g. `"Graphics/Renderer"`.
    public let id: String
    /// `SourceProject.id` this derives from, or `nil` for code original to Avalon.
    public let derivedFrom: String?
    /// Files in the source project this was taken or adapted from.
    public let sourcePaths: [String]
    public let stage: IntegrationStage
    /// What was changed and why — the part a licence notice cannot express.
    public let adaptationNotes: String

    public init(id: String, derivedFrom: String?, sourcePaths: [String] = [],
                stage: IntegrationStage, adaptationNotes: String = "") {
        self.id = id; self.derivedFrom = derivedFrom; self.sourcePaths = sourcePaths
        self.stage = stage; self.adaptationNotes = adaptationNotes
    }
}
