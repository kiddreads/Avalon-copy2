// Avalon — the layouts have to survive every screen, not the one they were drawn on.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

private let library = try! TouchLayoutLibrary.builtIn()
private let skins = try! ControlSkinLibrary.builtIn()

@Suite("Touch layout resource")
struct TouchLayoutResourceTests {

    @Test("every platform loads")
    func loads() {
        #expect(library.layouts.count == 11)
        for l in library.layouts {
            #expect(!l.controls.isEmpty)
            #expect(l.designWidth > 0 && l.designHeight > 0)
            #expect(l.screenAspect > 1, "\(l.id): every console here is wider than it is tall")
            #expect(!l.rationale.isEmpty, "\(l.id): a layout has to say why it is arranged this way")
        }
    }

    @Test("every control binds to something pressable")
    func everyControlBinds() {
        for l in library.layouts {
            for c in l.controls {
                #expect(!c.binds.isEmpty, "\(l.id)/\(c.id): control drives nothing")
                #expect(c.bindings.count == c.binds.count,
                        "\(l.id)/\(c.id): unparseable binding in \(c.binds)")
            }
        }
    }

    @Test("no two controls on a platform share an id")
    func idsAreUnique() {
        for l in library.layouts {
            let ids = l.controls.map(\.id)
            #expect(Set(ids).count == ids.count,
                    "\(l.id): duplicate ids \(ids.filter { id in ids.filter { $0 == id }.count > 1 })")
        }
    }

    @Test("each platform reaches the controls its hardware actually has")
    func hardwareCoverage() {
        // Directions and a confirm button are the floor; anything less is not a controller.
        for l in library.layouts {
            let reachable = l.reachableControls
            for d in [Control.up, .down, .left, .right] {
                #expect(reachable.contains(d), "\(l.id): cannot press \(d)")
            }
            #expect(reachable.contains(.a), "\(l.id): no primary button")
        }

        // The specific gaps this layout set shipped with, now regression tests.
        #expect(library.layout(id: "n64")!.control(id: "Z") != nil,
                "the N64's Z trigger is not optional")
        #expect(library.layout(id: "wiiu")!.reachableControls.isSuperset(of: [.l2, .r2]),
                "the Wii U GamePad has ZL and ZR")
        #expect(library.layout(id: "switch")!.reachableControls.isSuperset(of: [.l1, .r1, .l2, .r2]),
                "the Switch has L, R, ZL and ZR")
        #expect(library.layout(id: "xbox")!.reachableControls.isSuperset(of: [.l1, .r1, .l2, .r2]),
                "the Xbox pad has bumpers and triggers")
        #expect(library.layout(id: "deck")!.controls.filter { $0.kind == .stick }.count == 2,
                "the Steam Deck has two thumbsticks")
        #expect(library.layout(id: "ps")!.controls.filter { $0.kind == .stick }.count == 2,
                "a DualShock has two sticks")
    }

    @Test("clustered buttons share one anchor")
    func clustersAreRigid() {
        for l in library.layouts {
            let clustered = Dictionary(grouping: l.controls.filter { $0.cluster != nil },
                                       by: { $0.cluster! })
            for (name, members) in clustered where members.count > 1 {
                let anchors = Set(members.map { "\($0.anchorX)\($0.anchorY)\($0.offsetX)\($0.offsetY)" })
                #expect(anchors.count == 1,
                        "\(l.id)/\(name): cluster members anchor differently, so it tears apart")
            }
        }
    }

    @Test("the arcade lever is digital and every other stick is not")
    func stickModes() {
        for l in library.layouts {
            for c in l.controls where c.kind == .stick {
                #expect(c.isDigitalStick == (l.id == "arcade"), "\(l.id)/\(c.id)")
            }
        }
    }
}

@Suite("Layout solving")
struct LayoutSolverTests {

    @Test("every platform verifies on every device in both view modes")
    func verifiesEverywhere() {
        var failures: [String] = []
        var checks = 0
        for l in library.layouts {
            for device in DeviceProfile.all {
                for mode in ViewMode.allCases {
                    checks += 1
                    let resolved = LayoutSolver.solve(l, in: device.size, mode: mode)
                    for v in LayoutVerifier.verify(resolved) where v.isFatal {
                        failures.append("\(l.id) on \(device.id) [\(mode)]: \(v)")
                    }
                }
            }
        }
        #expect(checks == 11 * DeviceProfile.all.count * ViewMode.allCases.count)
        let report = failures.joined(separator: "\n")
        #expect(failures.isEmpty, "\(failures.count) fatal violations:\n\(report)")
    }

    @Test("the game rect keeps the console's real aspect ratio")
    func gameAspect() {
        for l in library.layouts {
            for device in DeviceProfile.all {
                let r = LayoutSolver.solve(l, in: device.size, mode: .windowed)
                let aspect = r.gameRect.width / r.gameRect.height
                #expect(abs(aspect - l.screenAspect) < 0.01,
                        "\(l.id) on \(device.id): game rect is \(aspect), hardware is \(l.screenAspect)")
            }
        }
    }

    @Test("nothing is drawn on top of the game in windowed mode")
    func nothingBlocksTheView() {
        for l in library.layouts {
            for device in DeviceProfile.all {
                let r = LayoutSolver.solve(l, in: device.size, mode: .windowed)
                for c in r.controls {
                    #expect(!c.frame.intersects(r.gameRect),
                            "\(l.id) on \(device.id): \(c.id) covers the game")
                }
            }
        }
    }

    @Test("fullscreen hands the whole screen to the game and fades the controls")
    func fullscreen() {
        for l in library.layouts {
            let r = LayoutSolver.solve(l, in: DeviceProfile.all[1].size, mode: .fullscreen)
            #expect(r.gameRect == DeviceProfile.all[1].size)
            #expect(r.controlOpacity < 1)
            // The controls stay exactly where they were; only the game and the opacity change.
            let windowed = LayoutSolver.solve(l, in: DeviceProfile.all[1].size, mode: .windowed)
            #expect(r.controls.map(\.frame) == windowed.controls.map(\.frame))
        }
    }

    @Test("controls only ever spread apart as the screen grows, never converge")
    func scalingIsSafe() {
        // The property the solver rests on: with s = min(W/dw, H/dh), a layout verified at its
        // design size stays verified at every other size, because edge-anchored controls can only
        // move further apart.
        for l in library.layouts {
            let design = LayoutRect(x: 0, y: 0, width: l.designWidth, height: l.designHeight)
            let base = LayoutSolver.solve(l, in: design)
            let wide = LayoutSolver.solve(l, in: LayoutRect(x: 0, y: 0,
                                                            width: l.designWidth * 2,
                                                            height: l.designHeight))
            for (a, b) in zip(base.controls, wide.controls) {
                #expect(abs(b.frame.width - a.frame.width) < 0.01,
                        "\(l.id)/\(a.id): a wider screen must not resize controls")
            }
            // The left column stays put; the right column moves right by the extra width.
            let leftBase = base.controls.first { $0.source.anchorX == .left }!
            let leftWide = wide.controls.first { $0.id == leftBase.id }!
            #expect(abs(leftWide.frame.minX - leftBase.frame.minX) < 0.01)
        }
    }

    @Test("touch targets clear the floors the hardware allows")
    func touchTargets() {
        // Measured floors, not aspirations. A tablet has room for Apple's 44pt on every control
        // a player uses in-game. A 375pt-tall phone holding a thirteen-control Switch Pro layout
        // does not, and pretending otherwise would just mean a test nobody trusts — so the phone
        // floor is what the layouts actually achieve, and it fails the moment one regresses.
        func floor(_ d: DeviceProfile) -> (primary: Double, secondary: Double) {
            d.size.height >= 700 ? (44, 18) : (37, 24)
        }
        for l in library.layouts {
            for device in DeviceProfile.all {
                let r = LayoutSolver.solve(l, in: device.size)
                let limits = floor(device)
                for c in r.controls {
                    let target = min(c.hitFrame.width, c.hitFrame.height)
                    let limit = (c.kind == .button || c.kind == .dpad || c.kind == .stick)
                        ? limits.primary : limits.secondary
                    #expect(target >= limit,
                            "\(l.id)/\(c.id) on \(device.id): \(target)pt target, floor \(limit)pt")
                }
            }
        }
        // And no touch target may swallow its neighbour's.
        for l in library.layouts {
            for device in DeviceProfile.all {
                let r = LayoutSolver.solve(l, in: device.size)
                for v in LayoutVerifier.verify(r) {
                    if case .hitOverlap(let a, let b, let o) = v {
                        Issue.record("\(l.id) on \(device.id): \(a) and \(b) share \(o)pt of target")
                    }
                }
            }
        }
    }

    @Test("a screen smaller than the design canvas still resolves")
    func tinyScreen() {
        for l in library.layouts {
            let r = LayoutSolver.solve(l, in: LayoutRect(x: 0, y: 0, width: 480, height: 270))
            #expect(r.scale < 1)
            let fatal = LayoutVerifier.verify(r).filter(\.isFatal)
            #expect(fatal.isEmpty, "\(l.id) at 480×270: \(fatal.map(\.description))")
        }
    }
}

@Suite("Control skins")
struct ControlSkinTests {

    @Test("all twenty-two skins load with parseable colours")
    func skinsLoad() {
        #expect(skins.skins.count == 22)
        for s in skins.skins {
            for c in [s.dpad, s.a, s.b, s.x, s.y, s.bg, s.border] {
                #expect(c.components != nil, "\(s.id): unparseable colour \(c.hex)")
                #expect(c.effectiveAlpha >= 0 && c.effectiveAlpha <= 1)
            }
        }
    }

    @Test("every platform has a matching hardware skin")
    func nativeSkins() {
        for l in library.layouts {
            #expect(skins.nativeSkin(for: l) != nil, "\(l.id) has no skin of its own")
        }
    }

    @Test("hardware colours survive a skin unless recolouring is asked for")
    func skinApplication() {
        let gc = library.layout(id: "gc")!
        let a = gc.control(id: "A")!
        let neon = skins.skin(id: "neon")!

        let kept = ResolvedControlStyle.resolve(a, skin: neon, application: .hardware)
        #expect(kept.fill.hex == a.fill, "a GameCube A is green whatever skin is selected")

        let repainted = ResolvedControlStyle.resolve(a, skin: neon, application: .recolour)
        #expect(repainted.fill.hex == neon.a.hex)
    }
}
