// Avalon — a layout that cannot be pressed is art, not a control layout.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

private let library = try! TouchLayoutLibrary.builtIn()
private let phone = DeviceProfile(id: "test", name: "test", width: 852, height: 393)

private func router(_ id: String) -> (TouchRouter, ResolvedLayout) {
    let resolved = LayoutSolver.solve(library.layout(id: id)!, in: phone.size)
    return (TouchRouter(layout: resolved), resolved)
}

@Suite("Touch routing")
struct TouchRouterTests {

    @Test("pressing a face button produces its control, releasing produces the zero")
    func pressAndRelease() {
        let (r, layout) = router("snes")
        let a = layout.control(id: "A")!
        let down = r.process(touches: [Touch(id: 1, location: a.centre)])
        #expect(down.contains { $0.control == .a && $0.value == 1 })
        #expect(r.value(of: .a) == 1)

        let up = r.process(touches: [])
        #expect(up.contains { $0.control == .a && $0.value == 0 })
        #expect(r.value(of: .a) == 0)
    }

    @Test("a held button emits once, not every frame")
    func noRepeats() {
        let (r, layout) = router("nes")
        let a = layout.control(id: "A")!
        #expect(r.process(touches: [Touch(id: 1, location: a.centre)]).count == 1)
        #expect(r.process(touches: [Touch(id: 1, location: a.centre)]).isEmpty)
    }

    @Test("the d-pad gives cardinals at the edges and diagonals in the corners")
    func dpadDirections() {
        let (r, layout) = router("nes")
        let d = layout.control(id: "dpad")!
        let reach = d.frame.width / 2 * 0.8

        func press(_ dx: Double, _ dy: Double) -> Set<Control> {
            _ = r.releaseAll()
            let p = LayoutPoint(x: d.centre.x + dx * reach, y: d.centre.y + dy * reach)
            _ = r.process(touches: [Touch(id: 1, location: p)])
            return Set([Control.up, .down, .left, .right].filter { r.value(of: $0) == 1 })
        }

        #expect(press(0, -1) == [.up])
        #expect(press(0, 1) == [.down])
        #expect(press(-1, 0) == [.left])
        #expect(press(1, 0) == [.right])
        #expect(press(0.7, -0.7) == [.up, .right])
        #expect(press(-0.7, 0.7) == [.down, .left])
        // A thumb resting dead centre presses nothing.
        _ = r.releaseAll()
        _ = r.process(touches: [Touch(id: 1, location: d.centre)])
        #expect([Control.up, .down, .left, .right].allSatisfy { r.value(of: $0) == 0 })
    }

    @Test("a stick reports a vector, clamped to full deflection, with screen y inverted")
    func stickVector() {
        let (r, layout) = router("ps")
        let stick = layout.control(id: "leftStick")!

        _ = r.process(touches: [Touch(id: 1, location:
            LayoutPoint(x: stick.centre.x + stick.radius / 2, y: stick.centre.y))])
        #expect(abs(r.value(of: .leftStickX) - 0.5) < 0.01)
        #expect(abs(r.value(of: .leftStickY)) < 0.01)

        // Pushing up the screen is +Y on the stick.
        _ = r.releaseAll()
        _ = r.process(touches: [Touch(id: 1, location:
            LayoutPoint(x: stick.centre.x, y: stick.centre.y - stick.radius / 2))])
        #expect(abs(r.value(of: .leftStickY) - 0.5) < 0.01)

        // Dragging beyond the gate stays at full deflection, never past it — and the stick keeps
        // tracking the finger well outside its own circle, which is what makes one usable.
        _ = r.releaseAll()
        _ = r.process(touches: [Touch(id: 1, location: stick.centre)])
        _ = r.process(touches: [Touch(id: 1, location:
            LayoutPoint(x: stick.centre.x + stick.radius * 4, y: stick.centre.y))])
        #expect(abs(r.value(of: .leftStickX) - 1) < 0.01)
    }

    @Test("an arcade lever is four switches, not an axis")
    func arcadeLeverIsDigital() {
        let (r, layout) = router("arcade")
        let lever = layout.control(id: "stick")!
        _ = r.process(touches: [Touch(id: 1, location:
            LayoutPoint(x: lever.centre.x - lever.radius * 0.8, y: lever.centre.y))])
        #expect(r.value(of: .left) == 1)
        #expect(r.value(of: .leftStickX) == 0)
    }

    @Test("the N64 C-buttons drive the right stick's axis ends")
    func cButtonsAreTheRightStick() {
        let (r, layout) = router("n64")
        _ = r.process(touches: [Touch(id: 1, location: layout.control(id: "◀")!.centre)])
        #expect(r.value(of: .rightStickX) == -1)
        _ = r.releaseAll()
        _ = r.process(touches: [Touch(id: 1, location: layout.control(id: "▲")!.centre)])
        #expect(r.value(of: .rightStickY) == 1)
    }

    @Test("the Deck's left pad is a pointer and its right pad is a stick")
    func trackpads() {
        let (r, layout) = router("deck")
        let left = layout.control(id: "leftPad")!
        _ = r.process(touches: [Touch(id: 1, location: left.frame.centre)])
        #expect(abs(r.value(of: .touchX) - 0.5) < 0.02)
        #expect(r.value(of: .touch) == 1)

        _ = r.releaseAll()
        let right = layout.control(id: "rightPad")!
        _ = r.process(touches: [Touch(id: 2, location:
            LayoutPoint(x: right.frame.maxX - 1, y: right.frame.centre.y))])
        #expect(r.value(of: .rightStickX) > 0.9)
    }

    @Test("two thumbs work at once")
    func multitouch() {
        let (r, layout) = router("xbox")
        let a = layout.control(id: "A")!
        let d = layout.control(id: "dpad")!
        _ = r.process(touches: [
            Touch(id: 1, location: a.centre),
            Touch(id: 2, location: LayoutPoint(x: d.centre.x - d.frame.width * 0.4, y: d.centre.y)),
        ])
        #expect(r.value(of: .a) == 1)
        #expect(r.value(of: .left) == 1)
    }

    @Test("a finger keeps the control it landed on while it slides")
    func captureSurvivesASlide() {
        let (r, layout) = router("snes")
        let a = layout.control(id: "A")!
        _ = r.process(touches: [Touch(id: 1, location: a.centre)])
        // Roll the thumb just past the button's edge; a real press does this constantly.
        let rolled = LayoutPoint(x: a.centre.x + a.hitRadius + 6, y: a.centre.y)
        _ = r.process(touches: [Touch(id: 1, location: rolled)])
        #expect(r.value(of: .a) == 1, "the press dropped when the thumb rolled")
    }

    @Test("corners of a round button's box belong to what is behind them")
    func roundHitTesting() {
        let (_, layout) = router("ps")
        let circle = layout.control(id: "○")!
        let corner = LayoutPoint(x: circle.hitFrame.maxX - 1, y: circle.hitFrame.maxY - 1)
        let r = TouchRouter(layout: layout)
        #expect(r.hitTest(corner)?.id != circle.id)
    }

    @Test("everything releases when the layout changes underneath")
    func layoutChangeReleases() {
        let (r, layout) = router("gc")
        _ = r.process(touches: [Touch(id: 1, location: layout.control(id: "A")!.centre)])
        #expect(r.value(of: .a) == 1)
        let other = LayoutSolver.solve(library.layout(id: "gc")!,
                                       in: LayoutRect(x: 0, y: 0, width: 1194, height: 834))
        let released = r.update(layout: other)
        #expect(released.contains { $0.control == .a && $0.value == 0 })
        #expect(r.value(of: .a) == 0)
    }

    @Test("every button on every platform is reachable by a touch at its centre")
    func everyControlIsReachable() {
        for l in library.layouts {
            for device in DeviceProfile.all {
                let resolved = LayoutSolver.solve(l, in: device.size)
                let r = TouchRouter(layout: resolved)
                for c in resolved.controls {
                    let hit = r.hitTest(c.centre)
                    #expect(hit?.id == c.id,
                            "\(l.id) on \(device.id): a touch at \(c.id)'s centre hits \(hit?.id ?? "nothing")")
                }
            }
        }
    }

    @Test("touch events reach a core through the normal input path")
    func endToEnd() {
        let (r, layout) = router("nes")
        // The NES core's own encoding, as Folium's Kiwi expects it.
        let map = CoreInputMap(coreID: "test.nes", mapping: [.a: 1, .b: 2, .start: 8, .select: 4,
                                                             .up: 16, .down: 32, .left: 64, .right: 128])
        let input = InputRouter(map: map)
        let events = r.process(touches: [Touch(id: 1, location: layout.control(id: "A")!.centre)])
        let issued = events.compactMap { input.handle($0) }
        #expect(issued.contains { $0.raw == 1 && $0.value == 1 })
        #expect(input.unmappedControls.isEmpty)
    }
}
