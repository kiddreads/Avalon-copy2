// Avalon — documentation verifier.
//
// The brief asks for an engineering map that "remains synchronized with the actual codebase". A
// document cannot do that by intention. This checks it.
//
// Every `path:line` citation in Avalon's docs and source comments is an assertion about the
// repository. This resolves each one and fails if the file is gone or the line is out of range —
// so a reorganisation of a source project breaks the build rather than quietly making the
// engineering map wrong.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonCore

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .deletingLastPathComponent()   // run from Avalon/, citations are repo-relative

struct Citation: Hashable { let path: String; let line: Int?; let source: String }

/// A citation written with an elision, e.g. `Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Cores/FDS.swift`. Readable in prose but
/// not resolvable, so it cannot be checked and is reported separately rather than as an error.
func isElided(_ path: String) -> Bool { path.contains("/.../") }

/// Matches `Some/Path/File.ext:123` and bare `Some/Path/File.ext`, inside backticks or prose.
// Alternation is longest-first on purpose: with "c" before "cs", a .cs path silently matches
// as ".c" and the verifier reports a file that was never cited. Found by running this on itself.
let pattern = #"((?:[A-Za-z0-9_./!\-]+(?: [A-Za-z0-9_./!\-]+)*)\.(?:swift|metal|json|hpp|cpp|txt|inl|mm|cs|md|h|m|c))(?::(\d+))?"#
let regex = try! NSRegularExpression(pattern: pattern)

func citations(in text: String, source: String) -> [Citation] {
    let ns = text as NSString
    return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
        let path = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        // Only check paths that name a real top-level project or Avalon itself.
        let roots = ["Delta/", "Fin/", "Folium/", "Manic EMU/", "MeloNX/", "PPSSPP/",
                     "Play!/", "dolphin-ios/", "iCube/", "iPSX2/", "Sources/", "Tests/", "docs/"]
            + externalRoots
        guard roots.contains(where: { path.hasPrefix($0) }) else { return nil }
        let line = m.range(at: 2).location != NSNotFound
            ? Int(ns.substring(with: m.range(at: 2))) : nil
        return Citation(path: path, line: line, source: source)
    }
}

/// Projects Avalon cites that are NOT inside this repository. muffin is the user's own separate
/// repo and sits beside this one, so its citations resolve against the parent directory. If it is
/// not checked out there, its citations count as skipped rather than as broken documentation.
let externalRoots = ["cemu-ios-muffin/"]

func scan(_ dir: URL, extensions: Set<String>) -> [URL] {
    guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
    return e.compactMap { $0 as? URL }.filter {
        extensions.contains($0.pathExtension) && !$0.path.contains("/.build/")
    }
}

var all: [Citation] = []
let avalonDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
for f in scan(avalonDir, extensions: ["md", "swift", "h", "c"]) {
    guard let text = try? String(contentsOf: f, encoding: .utf8) else { continue }
    let rel = f.path.replacingOccurrences(of: avalonDir.path + "/", with: "")
    all.append(contentsOf: citations(in: text, source: rel))
}

var checked = 0, missingFile = 0, badLine = 0, skipped = 0, elided = 0
var elidedPaths: Set<String> = []
var failures: [String] = []

for c in Set(all) {
    if isElided(c.path) { elided += 1; elidedPaths.insert(c.path); continue }
    // Avalon's own paths are relative to Avalon/; source-project paths to the repo root.
    let isAvalonPath = c.path.hasPrefix("Sources/") || c.path.hasPrefix("Tests/") || c.path.hasPrefix("docs/")
    let isExternal = externalRoots.contains { c.path.hasPrefix($0) }
    let base = isAvalonPath ? avalonDir : (isExternal ? repoRoot.deletingLastPathComponent() : repoRoot)
    let url = base.appendingPathComponent(c.path)

    guard FileManager.default.fileExists(atPath: url.path) else {
        // A source project may simply not be in the sparse checkout; that is not a doc error.
        if !isAvalonPath, !FileManager.default.fileExists(atPath:
            base.appendingPathComponent(String(c.path.prefix(while: { $0 != "/" }))).path) {
            skipped += 1; continue
        }
        missingFile += 1
        failures.append("  missing file: \(c.path)   (cited in \(c.source))")
        continue
    }
    checked += 1
    guard let line = c.line,
          let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
    // An LFS pointer is a stand-in, not the file; its line count means nothing.
    if text.hasPrefix("version https://git-lfs") { continue }
    // Swift treats "\r\n" as ONE Character, so split(separator: "\n") finds nothing in a CRLF
    // file and reports it as a single line. Several files in this repository are CRLF. Count
    // scalars instead. (This verifier found that bug in itself.)
    let count = text.unicodeScalars.reduce(0) { $0 + ($1 == "\n" ? 1 : 0) } + 1
    if line > count {
        badLine += 1
        failures.append("  line \(line) past end (\(count) lines): \(c.path)   (cited in \(c.source))")
    }
}

// The registry's licence paths are assertions too.
var licenceFailures: [String] = []
if let registry = try? ProjectRegistry.bundled() {
    for p in registry.projects {
        let url = repoRoot.appendingPathComponent(p.licensePath)
        let projectPresent = FileManager.default.fileExists(
            atPath: repoRoot.appendingPathComponent(p.id).path)
        if projectPresent && !FileManager.default.fileExists(atPath: url.path) {
            licenceFailures.append("  \(p.id): licence not at \(p.licensePath)")
        }
    }
    // External sources resolve against the parent directory, and their licence text is the
    // evidence for the compatibility claim Avalon makes about them.
    for e in registry.externalSources ?? [] {
        let root = repoRoot.deletingLastPathComponent()
        let url = root.appendingPathComponent(e.licensePath)
        let present = FileManager.default.fileExists(
            atPath: root.appendingPathComponent(e.id).path)
        if present && !FileManager.default.fileExists(atPath: url.path) {
            licenceFailures.append("  \(e.id): licence not at \(e.licensePath) (external)")
        }
    }
}

print("Avalon documentation verification")
print("  citations resolved      \(checked)")
print("  skipped (not checked out) \(skipped)")
print("  missing files           \(missingFile)")
print("  line numbers past EOF   \(badLine)")
print("  licence paths bad       \(licenceFailures.count)")
print("  elided (unverifiable)   \(elided) across \(elidedPaths.count) distinct paths")

let problems = failures + licenceFailures
if !elidedPaths.isEmpty {
    print("\nElided citations (readable, but not machine-checkable):")
    for p in elidedPaths.sorted() { print("  \(p)") }
}

if problems.isEmpty {
    print("\nAll resolvable citations check out.")
} else {
    print("\nProblems:")
    for p in problems.sorted() { print(p) }
}
exit(problems.isEmpty ? 0 : 1)
