// Avalon — license model.
//
// Avalon is assembled from projects under several different licenses. Combining them is legal only
// in specific directions, and getting that wrong is not a formatting mistake — it is a
// redistribution violation. This file makes the rules explicit and checkable rather than tribal.
//
// The GPL-2.0-only case is not hypothetical: Gambatte, the Game Boy core inside `Folium/Kiwi`, is
// GPL-2.0-only (`Folium/Kiwi/System/gambatte.cpp:4-6` — "version 2", no "or later" grant). It is
// therefore incompatible with the GPL-3.0 licence Folium itself ships under, and with Avalon if
// Avalon lands on GPL-3.0/AGPL-3.0. `combinedLicense(of:)` returns nil for that pairing on purpose.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A license carried by a source project, or by a core vendored inside one.
public enum License: String, Codable, Sendable, CaseIterable {
    /// Permissive, no copyleft. Imposes attribution only.
    case mit = "MIT"
    /// Play! — `Play!/License.txt` has two "Redistributions" clauses, not three.
    case bsd2Clause = "BSD-2-Clause"
    case bsd3Clause = "BSD-3-Clause"
    /// Weak copyleft; compatible with GPLv3 but imposes a relinking obligation.
    case lgpl3OrLater = "LGPL-3.0-or-later"
    /// Not an open-source license. Manic EMU gates several libretro cores this way
    /// (`Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Others/EmulationCore.swift:146-148` `nonCommercialCores`). A "no commercial use"
    /// term is an additional restriction, which GPL §7 forbids — such a core cannot be combined
    /// into a GPL/AGPL work at all.
    case nonCommercial = "NonCommercial"
    /// GPL v2 with **no** "or any later version" grant. Cannot be combined with GPLv3 or AGPLv3.
    case gpl2Only = "GPL-2.0-only"
    /// GPL v2 *with* the "or any later version" grant — relicensable upward to v3.
    case gpl2OrLater = "GPL-2.0-or-later"
    /// File-level copyleft. Cemu, and so muffin, ship under it
    /// (`cemu-ios-muffin/LICENSE.txt`). MPL §3.3 lets a covered file be distributed under a
    /// Secondary License — GPL 2.0+, LGPL 2.1+ or AGPL 3.0+ — *unless* the file carries the
    /// Exhibit B "Incompatible With Secondary Licenses" notice. No file under
    /// `cemu-ios-muffin/src/ios/App/` carries it, so muffin's skin work can enter an AGPL build
    /// with its own files staying MPL and their notices preserved.
    case mpl2 = "MPL-2.0"
    case gpl3OrLater = "GPL-3.0-or-later"
    case agpl3OrLater = "AGPL-3.0-or-later"

    /// The GPL generation this license can be exercised at, for compatibility purposes.
    /// `nil` for permissive licenses, which impose no generation of their own.
    private var reachableGenerations: Set<Int>? {
        switch self {
        case .mit, .bsd2Clause, .bsd3Clause: return nil   // compatible with anything
        case .gpl2Only: return [2]                        // v2 and only v2
        case .gpl2OrLater: return [2, 3]                  // may be exercised as either
        case .mpl2: return [2, 3]                         // §3.3 Secondary Licenses
        case .gpl3OrLater, .agpl3OrLater, .lgpl3OrLater: return [3]
        case .nonCommercial: return []                    // combines with nothing copyleft
        }
    }

    /// How strong the copyleft is, used to pick the license a combined work must carry.
    var copyleftRank: Int {
        switch self {
        case .mit, .bsd2Clause, .bsd3Clause: return 0
        case .mpl2: return 1            // copyleft, but per file rather than per work
        case .gpl2Only, .gpl2OrLater: return 1
        case .lgpl3OrLater, .gpl3OrLater: return 2
        case .agpl3OrLater: return 3
        case .nonCommercial: return 4   // never actually returned; combination fails first
        }
    }

    /// Whether this license requires source disclosure for *network* use (AGPL §13).
    public var hasNetworkClause: Bool { self == .agpl3OrLater }

    /// Whether binaries must be accompanied by corresponding source.
    public var requiresSourceDisclosure: Bool {
        switch self {
        case .mit, .bsd2Clause, .bsd3Clause: return false
        default: return true
        }
    }

    /// Whether this license permits commercial distribution at all.
    public var permitsCommercialUse: Bool { self != .nonCommercial }
}

public extension License {
    /// The license a single combined work must carry when these licenses are linked together,
    /// or `nil` if they cannot legally be combined at all.
    ///
    /// The rule: every copyleft license in the set must be exercisable at one common GPL
    /// generation. GPL-2.0-only reaches generation 2 alone; GPL-3.0/AGPL-3.0 reach 3 alone;
    /// GPL-2.0-or-later reaches either. So mixing GPL-2.0-only with any v3 license yields `nil`.
    /// Permissive licenses constrain nothing and are absorbed.
    static func combinedLicense(of licenses: some Sequence<License>) -> License? {
        let all = Array(licenses)
        guard !all.isEmpty else { return nil }

        // Intersect the generations every copyleft component can be exercised at.
        // A non-commercial term is an additional restriction; GPL §7 forbids it outright.
        if all.contains(.nonCommercial) && all.count > 1 { return nil }

        let constrained = all.compactMap(\.reachableGenerations)
        if constrained.isEmpty { return all.max { $0.copyleftRank < $1.copyleftRank } }
        let common = constrained.reduce(into: Set([2, 3])) { $0.formIntersection($1) }
        guard !common.isEmpty else { return nil }

        let strongest = all.max { $0.copyleftRank < $1.copyleftRank }!
        // A set that can only be exercised at generation 2 cannot be described by a v3 license.
        if common == [2], strongest.copyleftRank >= 2 { return nil }
        return strongest
    }

    /// Whether `self` may be combined with every license in `others`.
    static func canCombine(_ licenses: some Sequence<License>) -> Bool {
        combinedLicense(of: licenses) != nil
    }
}
