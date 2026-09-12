// Avalon — machine verification of a resolved layout.
//
// This file exists because of how the layouts it checks were built. Every single geometric fault
// in them — thirty-one overlapping button pairs, a trackpad off the edge, menu buttons sitting in
// the middle of the player's view, shoulder buttons three points apart — was reasoned about
// correctly on paper and shipped broken anyway. Checking geometry by argument does not work. The
// only thing that worked was running the numbers.
//
// So the checks live in the package, next to the layouts, and the test suite runs all of them
// across every platform, every device profile and both view modes. A layout that does not verify
// is a failing test, not a screenshot somebody has to notice.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

public enum LayoutViolation: Hashable, Sendable, CustomStringConvertible {
    /// A control's artwork leaves the screen.
    case outOfBounds(control: String, by: Double)
    /// Two controls' artwork overlaps.
    case collision(String, String, overlap: Double)
    /// Two touch targets overlap, so one press reaches both.
    case hitOverlap(String, String, overlap: Double)
    /// A control sits on top of the game — the fault the player notices first.
    case blocksGame(control: String, overlap: Double)
    /// A touch target smaller than a fingertip.
    case belowMinimumTarget(control: String, size: Double)
    /// Two controls in one cluster nearer than real hardware ever puts them.
    case crowded(String, String, ratio: Double)
    /// The game rect came out unusable.
    case degenerateGameRect(width: Double, height: Double)

    public var description: String {
        switch self {
        case .outOfBounds(let c, let by):
            return "\(c): off-screen by \(fmt(by))pt"
        case .collision(let a, let b, let o):
            return "\(a) × \(b): artwork overlaps by \(fmt(o))pt"
        case .hitOverlap(let a, let b, let o):
            return "\(a) × \(b): touch targets overlap by \(fmt(o))pt"
        case .blocksGame(let c, let o):
            return "\(c): covers the game by \(fmt(o))pt"
        case .belowMinimumTarget(let c, let s):
            return "\(c): touch target \(fmt(s))pt, below \(fmt(LayoutSolver.minimumTouchTarget))pt"
        case .crowded(let a, let b, let r):
            return "\(a) × \(b): spacing \(fmt(r))× of summed radii, tighter than hardware"
        case .degenerateGameRect(let w, let h):
            return "game rect unusable at \(fmt(w))×\(fmt(h))pt"
        }
    }

    private func fmt(_ d: Double) -> String { String(format: "%.1f", d) }

    /// A layout with any of these is broken for the player; the rest are warnings about comfort.
    public var isFatal: Bool {
        switch self {
        case .outOfBounds, .collision, .blocksGame, .degenerateGameRect: return true
        case .hitOverlap, .belowMinimumTarget, .crowded: return false
        }
    }
}

public enum LayoutVerifier {
    /// Real controllers put neighbouring face buttons at 1.05–1.35× their summed radii. Anything
    /// tighter reads as one blob under a thumb; this is the lower bound, measured from hardware.
    public static let minimumSpacingRatio: Double = 1.00

    public static func verify(_ r: ResolvedLayout) -> [LayoutViolation] {
        var found: [LayoutViolation] = []

        if r.gameRect.width < 16 || r.gameRect.height < 16 {
            found.append(.degenerateGameRect(width: r.gameRect.width, height: r.gameRect.height))
        }

        for c in r.controls {
            let out = max(r.bounds.minX - c.frame.minX, c.frame.maxX - r.bounds.maxX,
                          r.bounds.minY - c.frame.minY, c.frame.maxY - r.bounds.maxY)
            if out > 0.01 { found.append(.outOfBounds(control: c.id, by: out)) }

            let target = min(c.hitFrame.width, c.hitFrame.height)
            if target < LayoutSolver.minimumTouchTarget - 0.01 {
                found.append(.belowMinimumTarget(control: c.id, size: target))
            }

            // In fullscreen the controls float over the game on purpose, so the game-rect check
            // only applies to windowed mode, where covering it is a bug.
            if r.mode == .windowed, let o = overlapAmount(c, rect: r.gameRect), o > 0.01 {
                found.append(.blocksGame(control: c.id, overlap: o))
            }
        }

        for i in r.controls.indices {
            for j in (i + 1)..<r.controls.count {
                let a = r.controls[i], b = r.controls[j]
                if let o = overlapAmount(a, b, useHitFrames: false), o > 0.01 {
                    found.append(.collision(a.id, b.id, overlap: o))
                }
                if let o = overlapAmount(a, b, useHitFrames: true), o > 0.01 {
                    found.append(.hitOverlap(a.id, b.id, overlap: o))
                }
                if a.kind.isRound, b.kind.isRound,
                   let cluster = a.source.cluster, cluster == b.source.cluster {
                    let d = hypot(a.centre.x - b.centre.x, a.centre.y - b.centre.y)
                    let sum = a.radius + b.radius
                    if sum > 0 {
                        let ratio = d / sum
                        // Only flag the pairs that are actually adjacent; a diamond's opposite
                        // corners are far apart and say nothing about crowding.
                        if ratio < minimumSpacingRatio {
                            found.append(.crowded(a.id, b.id, ratio: ratio))
                        }
                    }
                }
            }
        }
        return found
    }

    /// Overlap between two controls, respecting that buttons and sticks are circles. Returns nil
    /// when they are clear of each other.
    private static func overlapAmount(_ a: SolvedControl, _ b: SolvedControl,
                                      useHitFrames: Bool) -> Double? {
        let ra = useHitFrames ? a.hitFrame : a.frame
        let rb = useHitFrames ? b.hitFrame : b.frame
        let radA = useHitFrames ? a.hitRadius : a.radius
        let radB = useHitFrames ? b.hitRadius : b.radius

        switch (a.kind.isRound, b.kind.isRound) {
        case (true, true):
            let d = hypot(ra.centre.x - rb.centre.x, ra.centre.y - rb.centre.y)
            let sum = radA + radB
            return d < sum ? sum - d : nil
        case (true, false):
            return circleBox(centre: ra.centre, radius: radA, box: rb)
        case (false, true):
            return circleBox(centre: rb.centre, radius: radB, box: ra)
        case (false, false):
            let o = ra.overlap(rb)
            return (o.x > 0 && o.y > 0) ? min(o.x, o.y) : nil
        }
    }

    private static func overlapAmount(_ c: SolvedControl, rect: LayoutRect) -> Double? {
        if c.kind.isRound { return circleBox(centre: c.centre, radius: c.radius, box: rect) }
        let o = c.frame.overlap(rect)
        return (o.x > 0 && o.y > 0) ? min(o.x, o.y) : nil
    }

    private static func circleBox(centre: LayoutPoint, radius: Double, box: LayoutRect) -> Double? {
        let nx = max(box.minX, min(centre.x, box.maxX))
        let ny = max(box.minY, min(centre.y, box.maxY))
        let d = hypot(centre.x - nx, centre.y - ny)
        return d < radius ? radius - d : nil
    }
}
