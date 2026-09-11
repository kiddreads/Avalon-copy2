// Avalon — the registry of source projects Avalon draws from.
//
// Backed by Resources/projects.json so the inventory is data, not code. Everything in that file was
// checked against the repository; `notes` records how.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A core vendored *inside* a source project whose license differs from its host's.
///
/// These are the dangerous ones: a project's top-level LICENSE says nothing about what its
/// subdirectories actually carry, and two of them in this repository conflict with their own host.
public struct VendoredCore: Codable, Sendable, Hashable {
    public let host: String
    public let path: String
    public let name: String
    public let license: License
    /// `file:line` proving the license claim.
    public let evidence: String
    /// Why this matters, or empty if it is merely noteworthy.
    public let hazard: String

    public var isHazard: Bool { !hazard.isEmpty }
}

/// Data that must never be redistributed, regardless of the surrounding code's license.
public struct ExcludedData: Codable, Sendable, Hashable {
    public let path: String
    public let reason: String
}

public struct ProjectRegistry: Codable, Sendable {
    public struct Snapshot: Codable, Sendable {
        public let repo: String, commit: String, date: String
    }

    public let schemaVersion: Int
    public let snapshot: Snapshot
    public let projects: [SourceProject]
    public let vendoredCores: [VendoredCore]
    public let excludedData: [ExcludedData]

    /// The registry shipped with Avalon.
    public static func bundled() throws -> ProjectRegistry {
        guard let url = Bundle.module.url(forResource: "projects", withExtension: "json") else {
            throw RegistryError.manifestMissing
        }
        return try JSONDecoder().decode(ProjectRegistry.self, from: Data(contentsOf: url))
    }

    public enum RegistryError: Error, CustomStringConvertible {
        case manifestMissing
        public var description: String { "projects.json is not present in the AvalonCore bundle" }
    }

    public func project(_ id: String) -> SourceProject? { projects.first { $0.id == id } }

    /// Every distinct license in play, including those of vendored cores.
    ///
    /// Using only `projects.map(\.license)` here would be the exact mistake this type exists to
    /// prevent: it would miss Gambatte and report that everything combines cleanly.
    public var allLicensesInPlay: Set<License> {
        Set(projects.map(\.license)).union(vendoredCores.map(\.license))
    }

    /// The license a build containing *everything* would have to carry, or `nil` if no such build
    /// is legal. With the current contents this is `nil`, because of Gambatte.
    public var combinedLicenseIfEverythingIncluded: License? {
        License.combinedLicense(of: allLicensesInPlay)
    }

    /// The license Avalon actually targets: everything except the components that cannot be combined.
    public func combinedLicense(excluding excludedProjects: Set<String>) -> License? {
        let projectLicenses = projects.filter { !excludedProjects.contains($0.id) }.map(\.license)
        let coreLicenses = vendoredCores.filter { !$0.isHazard }.map(\.license)
        return License.combinedLicense(of: projectLicenses + coreLicenses)
    }

    public var hazards: [VendoredCore] { vendoredCores.filter(\.isHazard) }
}
