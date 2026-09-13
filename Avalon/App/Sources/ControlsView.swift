// Avalon — drawing and pressing a resolved layout.
//
// Every position, size and colour here comes from `LayoutSolver` and the layout resource; this
// file decides none of it. That is the point of solving layouts in the package: the view is a
// renderer, so the thing that gets shipped is the thing the tests verified.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SwiftUI
import UIKit
import AvalonCore

extension SkinColor {
    var swiftUI: Color {
        guard let c = components else { return .gray }
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: effectiveAlpha)
    }
}

/// Draws one resolved layout. Buttons and sticks are circles, everything else a rounded bar,
/// which is exactly the distinction the verifier uses when it checks them for overlap.
struct ControlsView: View {
    let layout: ResolvedLayout
    /// Controls currently held, so a press is visible.
    let pressed: Set<String>
    /// Which combination of bindings is active per d-pad control id (e.g. "up+right"), so a
    /// haptic tap can fire on a genuine new direction rather than on every touch-move. Empty for
    /// any control that isn't a d-pad, and safe to omit for layouts that predate this.
    let directions: [String: String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Prepared once and reused for the view's lifetime — never allocated per frame or per press —
    // and re-primed after firing so the Taptic Engine stays warm for the next one.
    @State private var buttonImpact = UIImpactFeedbackGenerator(style: .rigid)
    @State private var dpadImpact = UIImpactFeedbackGenerator(style: .light)

    init(layout: ResolvedLayout, pressed: Set<String>, directions: [String: String] = [:]) {
        self.layout = layout
        self.pressed = pressed
        self.directions = directions
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.controls, id: \.id) { control in
                shape(for: control)
                    .position(x: control.centre.x, y: control.centre.y)
                    // Touch goes through `TouchSurface` below, not through these shapes — but a
                    // VoiceOver user swiping through the screen still deserves to know a D-pad, an
                    // A button, a Start button and so on are here, and roughly what each is.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityDescription(for: control))
            }
        }
        .opacity(layout.controlOpacity)
        .allowsHitTesting(false)
        .onAppear {
            buttonImpact.prepare()
            dpadImpact.prepare()
        }
    }

    private func fireImpact(_ generator: UIImpactFeedbackGenerator) {
        generator.impactOccurred()
        generator.prepare()   // re-arm immediately so the next tap stays low-latency
    }

    /// A short, spoken description of what a control is. Informational only — there is no
    /// VoiceOver activation path for these, since real input travels through `TouchSurface`.
    private func accessibilityDescription(for control: SolvedControl) -> String {
        if let label = control.source.label, !label.isEmpty {
            switch control.kind {
            case .dpad, .trackpad, .stick: return label
            case .button, .pill, .shoulder: return "\(label) button"
            }
        }
        switch control.kind {
        case .dpad: return "Direction pad"
        case .stick: return control.source.isDigitalStick ? "Directional lever" : "Analog stick"
        case .trackpad: return "Touchpad"
        case .button, .pill, .shoulder: return "Control"
        }
    }

    @ViewBuilder
    private func shape(for control: SolvedControl) -> some View {
        let style = ResolvedControlStyle.resolve(control.source, skin: nil)
        let down = pressed.contains(control.id)
        let fill = style.fill.swiftUI

        switch control.kind {
        case .button:
            ZStack {
                Circle().fill(fill)
                Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                if let label = control.source.label {
                    Text(label)
                        .font(.system(size: max(9, control.radius * 0.8), weight: .semibold))
                        .foregroundStyle(style.labelColor?.swiftUI ?? .black)
                }
            }
            .frame(width: control.frame.width, height: control.frame.height)
            // A mechanical press: the cap sinks and darkens rather than merely tinting. Reduce
            // Motion drops the size change — still motion, however quick — but keeps the
            // darkening, and applies it instantly rather than eased.
            .scaleEffect(reduceMotion ? 1 : (down ? 0.92 : 1))
            .brightness(down ? -0.12 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.06), value: down)
            .onChange(of: down) { isDown in
                if isDown { fireImpact(buttonImpact) }
            }

        case .stick:
            ZStack {
                Circle().fill(fill.opacity(0.55))
                Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1)
                Circle()
                    .fill(style.capFill?.swiftUI ?? fill)
                    .frame(width: control.frame.width * 0.62,
                           height: control.frame.height * 0.62)
                    .shadow(radius: down ? 1 : 3)
            }
            .frame(width: control.frame.width, height: control.frame.height)
            // Deliberately no haptic here: a stick is dragged continuously, and tapping on every
            // frame of that motion would read as a buzz, not a press.

        case .dpad:
            let direction = directions[control.id] ?? ""
            DPadShape()
                .fill(fill)
                .overlay(DPadShape().stroke(.white.opacity(0.16), lineWidth: 1))
                .frame(width: control.frame.width, height: control.frame.height)
                .scaleEffect(reduceMotion ? 1 : (down ? 0.97 : 1))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.06), value: down)
                .onChange(of: direction) { newDirection in
                    // Fires on a genuine new direction, including the first press. Never fires on
                    // release (back to "") and never repeats while the same direction is held.
                    if !newDirection.isEmpty { fireImpact(dpadImpact) }
                }

        case .pill, .shoulder, .trackpad:
            ZStack {
                RoundedRectangle(cornerRadius: min(control.frame.height, control.frame.width) / 2.6)
                    .fill(fill)
                RoundedRectangle(cornerRadius: min(control.frame.height, control.frame.width) / 2.6)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                if let label = control.source.label {
                    Text(label)
                        .font(.system(size: max(8, control.frame.height * 0.42), weight: .semibold))
                        .foregroundStyle(style.labelColor?.swiftUI ?? .white)
                }
            }
            .frame(width: control.frame.width, height: control.frame.height)
            .scaleEffect(reduceMotion ? 1 : (down ? 0.96 : 1))
            .brightness(down ? -0.1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.06), value: down)
            .onChange(of: down) { isDown in
                // A trackpad is dragged like a stick, not tapped like a button or shoulder pad.
                if isDown, control.kind != .trackpad { fireImpact(buttonImpact) }
            }
        }
    }
}

/// A real cross, not a rounded square. The arms are what a thumb feels for.
struct DPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) / 3
        var p = Path()
        p.addRoundedRect(in: CGRect(x: rect.midX - arm / 2, y: rect.minY,
                                    width: arm, height: rect.height),
                         cornerSize: CGSize(width: arm * 0.28, height: arm * 0.28))
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.midY - arm / 2,
                                    width: rect.width, height: arm),
                         cornerSize: CGSize(width: arm * 0.28, height: arm * 0.28))
        return p
    }
}

/// Multitouch surface. SwiftUI gestures cannot report several independent fingers with identity,
/// which a controller needs, so this drops to UIKit for the one thing UIKit still does better.
struct TouchSurface: UIViewRepresentable {
    let onTouches: ([Touch]) -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.onTouches = onTouches
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: TouchTrackingView, context: Context) {
        view.onTouches = onTouches
    }
}

final class TouchTrackingView: UIView {
    var onTouches: (([Touch]) -> Void)?
    private var ids: [ObjectIdentifier: Int] = [:]
    private var nextID = 1

    private func report(_ event: UIEvent?) {
        let active = (event?.allTouches ?? []).filter {
            $0.phase != .ended && $0.phase != .cancelled
        }
        var touches: [Touch] = []
        var seen: [ObjectIdentifier: Int] = [:]
        for t in active {
            let key = ObjectIdentifier(t)
            let id = ids[key] ?? { defer { nextID += 1 }; return nextID }()
            seen[key] = id
            let p = t.location(in: self)
            touches.append(Touch(id: id, location: LayoutPoint(x: p.x, y: p.y)))
        }
        ids = seen
        onTouches?(touches)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
}
