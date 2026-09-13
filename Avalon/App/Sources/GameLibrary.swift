// Avalon — the player's games.
//
// Delta identifies a game by SHA-1 of its contents and looks metadata up offline; Manic EMU
// scrapes a network service. Delta is right, and this is the small version of it: the hash is the
// identity, so re-importing the same ROM under a different filename does not duplicate it, and a
// save state stays attached to the game rather than to a path.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import CryptoKit
import AvalonCore

struct Game: Identifiable, Codable, Hashable {
    /// SHA-1 of the file's contents.
    let id: String
    let title: String
    let fileName: String
    let systemID: String
    let importedAt: Date

    var system: SystemIdentifier { SystemIdentifier(systemID) }
    var profile: SystemProfile? { SystemCatalog.profile(for: system) }

    var url: URL { GameLibrary.gamesDirectory.appendingPathComponent(fileName) }
}

@MainActor
final class GameLibrary: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published var lastError: String?

    static let gamesDirectory: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Games", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private static var indexURL: URL {
        gamesDirectory.appendingPathComponent("library.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: Self.indexURL),
              let decoded = try? JSONDecoder().decode([Game].self, from: data) else { return }
        games = decoded.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(games) else { return }
        try? data.write(to: Self.indexURL, options: .atomic)
    }

    /// Import a file the player picked. `chosenSystem` resolves an ambiguous extension.
    func importGame(from source: URL, as chosenSystem: SystemIdentifier? = nil) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let ext = source.pathExtension
        let candidates = SystemCatalog.profiles(forExtension: ext)
        guard let profile = chosenSystem.flatMap(SystemCatalog.profile(for:)) ?? candidates.first else {
            lastError = ext.isEmpty
                ? "Avalon does not recognise that file — it has no file extension to go on."
                : "Avalon does not recognise .\(ext) files."
            return
        }

        do {
            let data = try Data(contentsOf: source)
            let hash = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if games.contains(where: { $0.id == hash }) {
                lastError = "\(source.deletingPathExtension().lastPathComponent) is already in your library."
                return
            }

            let stored = "\(hash).\(ext.lowercased())"
            let destination = Self.gamesDirectory.appendingPathComponent(stored)
            try data.write(to: destination, options: .atomic)

            games.append(Game(id: hash,
                              title: source.deletingPathExtension().lastPathComponent,
                              fileName: stored,
                              systemID: profile.id.rawValue,
                              importedAt: Date()))
            games.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            save()
        } catch {
            lastError = "Avalon could not import that file: \(error.localizedDescription)"
        }
    }

    func remove(_ game: Game) {
        try? FileManager.default.removeItem(at: game.url)
        games.removeAll { $0.id == game.id }
        save()
    }

    /// Games grouped by system, systems with a working core first.
    var sections: [(profile: SystemProfile, games: [Game])] {
        let grouped = Dictionary(grouping: games) { $0.systemID }
        return SystemCatalog.all.compactMap { profile in
            guard let list = grouped[profile.id.rawValue], !list.isEmpty else { return nil }
            return (profile, list)
        }
        .sorted { a, b in
            if a.profile.coreStatus.isAvailable != b.profile.coreStatus.isAvailable {
                return a.profile.coreStatus.isAvailable
            }
            return a.profile.shortName < b.profile.shortName
        }
    }
}
