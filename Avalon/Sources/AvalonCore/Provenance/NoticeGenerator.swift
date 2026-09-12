// Avalon — attribution generation.
//
// The brief asks for a provenance and attribution system, not a NOTICE file. The difference matters:
// a hand-written notice drifts the first time a component moves. This generates the notice from the
// same registry the licence checks read, so it cannot disagree with them.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

public extension ProjectRegistry {
    /// Render the attribution notice Avalon must ship.
    ///
    /// Includes superseded and excluded components deliberately: a reader needs to know that a
    /// project is present in the repository but not in the build, and why.
    func generateNotice(includeExcluded: Bool = true) -> String {
        var out = """
        # Avalon — Notices and Attribution

        Generated from `Sources/AvalonCore/Resources/projects.json`. Do not edit by hand.

        Repository snapshot: \(snapshot.repo) @ \(snapshot.commit) (\(snapshot.date))

        Avalon is assembled from the projects below. Each retains its own copyright and licence;
        this notice records them as those licences require.

        """

        let combined = combinedLicense(excluding: Set(projects.filter(\.isSuperseded).map(\.id)))
        out += "**Combined work licence:** \(combined?.rawValue ?? "NOT DISTRIBUTABLE — see hazards")\n"
        if combined?.hasNetworkClause == true {
            out += "\nBecause the combined work is AGPL-3.0, §13 applies: anyone interacting with an\n"
            out += "Avalon component over a network must be offered the corresponding source.\n"
        }

        out += "\n## Included projects\n\n"
        for p in projects.filter({ !$0.isSuperseded }).sorted(by: { $0.id < $1.id }) {
            out += "### \(p.id) — \(p.license.rawValue)\n\n"
            if let u = p.upstream { out += "- Upstream: \(u)\n" }
            if let o = p.origin { out += "- Source: \(o.absoluteString)\n" }
            if !p.copyrightHolders.isEmpty {
                out += "- Copyright: \(p.copyrightHolders.joined(separator: ", "))\n"
            }
            out += "- Licence text: `\(p.licensePath)`\n"
            if !p.systems.isEmpty { out += "- Systems: \(p.systems.joined(separator: ", "))\n" }
            out += "\n"
        }

        if let external = externalSources, !external.isEmpty {
            out += "## Drawn from outside this repository\n\n"
            out += "These are separate projects. Avalon uses work from them and the obligation to "
            out += "attribute it is the same as for anything in the tree.\n\n"
            for e in external.sorted(by: { $0.id < $1.id }) {
                out += "### \(e.id) — \(e.license.rawValue)\n\n"
                out += "- Source: \(e.origin.absoluteString)\n"
                if !e.copyrightHolders.isEmpty {
                    out += "- Copyright: \(e.copyrightHolders.joined(separator: ", "))\n"
                }
                out += "- Licence text: `\(e.licensePath)` (beside this repository)\n"
                out += "- Used for: \(e.usedFor)\n"
                out += "- \(e.notes)\n\n"
            }
        }

        let superseded = projects.filter(\.isSuperseded)
        if !superseded.isEmpty {
            out += "## Present in the repository but not in the build\n\n"
            for p in superseded {
                out += "- **\(p.id)** — superseded by `\(p.supersededBy ?? "")`.\n"
            }
            out += "\n"
        }

        guard includeExcluded else { return out }

        if !hazards.isEmpty {
            out += "## Components excluded for licence incompatibility\n\n"
            out += "These are present in source projects but must not enter an Avalon build.\n\n"
            for h in hazards.sorted(by: { $0.name < $1.name }) {
                out += "### \(h.name) — \(h.license.rawValue)\n\n"
                out += "- Location: `\(h.path)` (in \(h.host))\n"
                out += "- Evidence: `\(h.evidence)`\n"
                out += "- Reason: \(h.hazard)\n\n"
            }
        }

        if !excludedData.isEmpty {
            out += "## Data excluded from redistribution\n\n"
            for e in excludedData {
                out += "- `\(e.path)` — \(e.reason)\n"
            }
            out += "\n"
        }
        return out
    }
}
