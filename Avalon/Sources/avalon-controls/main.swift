// Avalon — control layout report.
//
// Prints what every layout actually resolves to on every device Avalon targets, and what the
// verifier says about it. The point is that the numbers are checkable from a terminal instead of
// being judged from a screenshot, which is how every geometric fault in these layouts got shipped.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonCore

let library = try TouchLayoutLibrary.builtIn()
let skins = try ControlSkinLibrary.builtIn()

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}
func f(_ d: Double) -> String { String(format: "%.1f", d) }

let verbose = CommandLine.arguments.contains("--verbose")
let only = CommandLine.arguments.first { $0.hasPrefix("--platform=") }?
    .replacingOccurrences(of: "--platform=", with: "")

var fatal = 0, warnings = 0

print("Avalon control layouts — \(library.layouts.count) platforms, \(skins.skins.count) skins\n")

for layout in library.layouts where only == nil || layout.id == only {
    let primary = layout.controls.filter { $0.kind == .button || $0.kind == .dpad || $0.kind == .stick }
    print("\(layout.name)  [\(layout.id)]  \(layout.hardware), \(layout.year)")
    print("  canvas \(f(layout.designWidth))×\(f(layout.designHeight))  screen \(f(layout.screenAspect)):1  "
          + "\(layout.controls.count) controls (\(primary.count) primary)")

    for device in DeviceProfile.all {
        let r = LayoutSolver.solve(layout, in: device.size, mode: .windowed)
        let issues = LayoutVerifier.verify(r)
        let fatals = issues.filter(\.isFatal)
        fatal += fatals.count
        warnings += issues.count - fatals.count

        func smallest(_ kinds: Set<ControlKind>) -> Double {
            r.controls.filter { kinds.contains($0.kind) }
                .map { min($0.hitFrame.width, $0.hitFrame.height) }.min() ?? 0
        }
        let primaryTarget = smallest([.button, .dpad, .stick])
        let secondaryTarget = smallest([.shoulder, .pill, .trackpad])

        let flag = fatals.isEmpty ? (primaryTarget >= 44 ? "ok  " : "small") : "FAIL"
        print("    \(pad(device.name, 22)) ×\(f(r.scale))  game \(pad(f(r.gameRect.width) + "×" + f(r.gameRect.height), 14))"
              + "primary ≥\(pad(f(primaryTarget), 6))secondary ≥\(pad(f(secondaryTarget), 6))\(flag)")

        if verbose || !fatals.isEmpty {
            for i in issues where verbose || i.isFatal { print("        \(i.isFatal ? "✗" : "·") \(i)") }
        }
    }
    print("")
}

print("fatal violations: \(fatal)   warnings: \(warnings)")
exit(fatal == 0 ? 0 : 1)
