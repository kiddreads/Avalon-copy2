// Avalon — resolving a layout onto a real screen.
//
// Nothing in the source projects does this. Delta and Manic EMU ship one artwork per
// (system, orientation, device class) and pick the nearest match — Delta's skins carry an
// explicit `representations` tree keyed by device and size, and a device outside that tree gets
// somebody else's positions. Muffin scales a single controller uniformly. Both approaches mean
// the layout is only correct on the screens somebody happened to draw it for.
//
// Avalon solves the layout instead. Positions are anchored to screen edges in design units, so
// one authored layout resolves onto any aspect ratio, and the result is checkable by machine
// (`LayoutVerifier`) rather than by eye on a simulator.
//
// The scale rule is what makes that safe. With `s = min(W/dw, H/dh)`, the device is at least as
// large as the design canvas times s in BOTH axes, so edge-anchored controls can only ever move
// further apart than they were authored — never closer. A cluster verified once at design size
// stays verified at every larger relative size. That is a property, not a hope, and the tests
// exercise it across the real device aspect ratios rather than asserting it in a comment.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Whether the game occupies the free space between the controls or the whole screen.
public enum ViewMode: String, Sendable, CaseIterable {
    /// The console's own aspect ratio, centred in the space the controls leave.
    case windowed
    /// The game fills the screen; controls float over it, translucent.
    case fullscreen
}

/// One control placed on a real screen.
public struct SolvedControl: Sendable, Identifiable {
    public let source: TouchControl
    /// The artwork's rectangle.
    public let frame: LayoutRect
    /// The touch target, grown toward the 44pt minimum but never into a neighbour.
    public let hitFrame: LayoutRect

    public var id: String { source.id }
    public var kind: ControlKind { source.kind }
    public var centre: LayoutPoint { frame.centre }
    /// Radius of a round control, in device points.
    public var radius: Double { min(frame.width, frame.height) / 2 }
    /// Radius of the round control's touch target.
    public var hitRadius: Double { min(hitFrame.width, hitFrame.height) / 2 }
}

/// A layout placed on a specific screen.
public struct ResolvedLayout: Sendable {
    public let layout: TouchLayout
    public let bounds: LayoutRect
    public let mode: ViewMode
    public let scale: Double
    public let controls: [SolvedControl]
    /// Where the emulated screen goes.
    public let gameRect: LayoutRect
    /// Opacity the controls should draw at; below 1 only in fullscreen.
    public let controlOpacity: Double

    public func control(id: String) -> SolvedControl? { controls.first { $0.id == id } }
}

public enum LayoutSolver {
    /// Apple's minimum comfortable touch target.
    public static let minimumTouchTarget: Double = 44

    /// Controls never grow past this multiple of their authored size; a tablet should give
    /// bigger buttons than a phone, but not a thumb-sized screen's worth of them.
    public static let maximumScale: Double = 1.25

    /// Breathing room between the controls and the game rect, in design units.
    public static let gutter: Double = 8

    public static func solve(_ layout: TouchLayout,
                             in size: LayoutRect,
                             mode: ViewMode = .windowed) -> ResolvedLayout {
        let scale = min(maximumScale,
                        min(size.width / layout.designWidth, size.height / layout.designHeight))

        var frames: [LayoutRect] = []
        frames.reserveCapacity(layout.controls.count)
        for c in layout.controls {
            let ax = c.anchorX == .left
                ? size.minX + c.offsetX * scale
                : size.maxX - c.offsetX * scale
            let ay = c.anchorY == .top
                ? size.minY + c.offsetY * scale
                : size.maxY - c.offsetY * scale
            let centre = LayoutPoint(x: ax + c.dx * scale, y: ay + c.dy * scale)
            frames.append(LayoutRect(centre: centre,
                                     width: c.width * scale,
                                     height: c.height * scale))
        }

        let hits = hitFrames(for: frames, within: size)
        let controls = zip(layout.controls, zip(frames, hits)).map {
            SolvedControl(source: $0, frame: $1.0, hitFrame: $1.1)
        }

        let game = mode == .fullscreen
            ? size
            : gameRect(for: layout, controls: controls, in: size, scale: scale)

        return ResolvedLayout(layout: layout, bounds: size, mode: mode, scale: scale,
                              controls: controls, gameRect: game,
                              controlOpacity: mode == .fullscreen ? 0.5 : 1.0)
    }

    /// The game rect is derived, never authored: the console's own aspect ratio, fitted into the
    /// space left over once the shoulder strip and the two control columns have taken theirs.
    ///
    /// Deriving it is the fix for the worst bug this layout set had — menu buttons sitting in the
    /// middle of the player's view. That happened because the safe area was drawn as a decorative
    /// dashed rectangle that no position was computed from. Here the game rect is a consequence of
    /// where the controls actually are, so it cannot disagree with them.
    private static func gameRect(for layout: TouchLayout,
                                 controls: [SolvedControl],
                                 in size: LayoutRect,
                                 scale: Double) -> LayoutRect {
        let pad = gutter * scale
        let midX = size.centre.x

        // The shoulder strip owns the top band across the full width.
        let strip = controls.filter { $0.kind == .shoulder }.map(\.frame.maxY).max() ?? size.minY

        // Everything else claims a column on its own side.
        let columns = controls.filter { $0.kind != .shoulder }
        let leftEdge = columns.filter { $0.centre.x < midX }.map(\.frame.maxX).max() ?? size.minX
        let rightEdge = columns.filter { $0.centre.x >= midX }.map(\.frame.minX).min() ?? size.maxX

        let band = LayoutRect(x: leftEdge + pad,
                              y: strip + pad,
                              width: max(0, (rightEdge - pad) - (leftEdge + pad)),
                              height: max(0, (size.maxY - pad) - (strip + pad)))
        return band.fittingAspect(layout.screenAspect)
    }

    /// Grow every touch target toward 44pt, but never past halfway to its nearest neighbour.
    ///
    /// A target that swallows the gap to the button beside it turns one mis-press into two, which
    /// is worse than a target that stays small. So the inflation each control gets is the smallest
    /// of: what it needs to reach 44pt, and half the separation to every other control.
    private static func hitFrames(for frames: [LayoutRect], within bounds: LayoutRect) -> [LayoutRect] {
        var inflation = frames.map { max(0, (minimumTouchTarget - min($0.width, $0.height)) / 2) }
        for i in frames.indices {
            guard inflation[i] > 0 else { continue }
            for j in frames.indices where j != i {
                let o = frames[i].overlap(frames[j])
                // Disjoint frames have a negative overlap on at least one axis; the least
                // negative of the two is the separation along the axis that separates them.
                let separation = -max(o.x, o.y)
                if separation <= 0 { inflation[i] = 0; break }
                inflation[i] = min(inflation[i], separation / 2)
            }
        }
        return zip(frames, inflation).map { frame, d in
            var r = frame.inflated(by: d)
            // Never let a target hang off the screen; slide it back in instead.
            if r.minX < bounds.minX { r.x = bounds.minX }
            if r.minY < bounds.minY { r.y = bounds.minY }
            if r.maxX > bounds.maxX { r.x = bounds.maxX - r.width }
            if r.maxY > bounds.maxY { r.y = bounds.maxY - r.height }
            return r
        }
    }
}

/// The screens Avalon is expected to run on, for verification and previews.
public struct DeviceProfile: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Landscape logical size in points.
    public let size: LayoutRect

    public init(id: String, name: String, width: Double, height: Double) {
        self.id = id
        self.name = name
        self.size = LayoutRect(x: 0, y: 0, width: width, height: height)
    }

    public var aspect: Double { size.width / size.height }

    /// Landscape point sizes as reported by the devices themselves.
    public static let all: [DeviceProfile] = [
        DeviceProfile(id: "iphone-se", name: "iPhone SE (3rd gen)", width: 667, height: 375),
        DeviceProfile(id: "iphone-15", name: "iPhone 15", width: 852, height: 393),
        DeviceProfile(id: "iphone-15-pro-max", name: "iPhone 15 Pro Max", width: 932, height: 430),
        DeviceProfile(id: "ipad-mini", name: "iPad mini", width: 1133, height: 744),
        DeviceProfile(id: "ipad-pro-11", name: "iPad Pro 11-inch", width: 1194, height: 834),
        DeviceProfile(id: "ipad-pro-13", name: "iPad Pro 13-inch", width: 1366, height: 1024),
    ]
}
