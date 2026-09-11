// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import AvalonCore

let registry = try ProjectRegistry.bundled()
let notice = registry.generateNotice()
if CommandLine.arguments.count > 1 {
    try notice.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
    FileHandle.standardError.write("wrote \(CommandLine.arguments[1])\n".data(using: .utf8)!)
} else {
    print(notice)
}
