// Avalon — the library.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers
import AvalonCore

struct ContentView: View {
    @StateObject private var library = GameLibrary()
    @State private var importing = false
    @State private var playing: Game?
    @State private var showingSystems = false

    /// Files picked but not yet handed to the library — held back only while one of them needs
    /// `pendingChoice` answered.
    @State private var importQueue: [URL] = []
    @State private var pendingChoice: AmbiguousImport?
    @State private var showingDisambiguation = false

    var body: some View {
        NavigationStack {
            Group {
                if library.games.isEmpty {
                    EmptyLibraryView { importing = true }
                } else {
                    List {
                        ForEach(library.sections, id: \.profile.id) { section in
                            Section {
                                ForEach(section.games) { game in
                                    GameRow(game: game, profile: section.profile) {
                                        playing = game
                                    }
                                }
                                .onDelete { offsets in
                                    for i in offsets { library.remove(section.games[i]) }
                                }
                            } header: {
                                SectionHeader(profile: section.profile)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Avalon")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSystems = true } label: {
                        Label("Systems", systemImage: "square.stack.3d.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: {
                        Label("Import", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSystems) { SystemsView() }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .item],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                importQueue.append(contentsOf: urls)
                advanceImportQueue()
            }
        }
        .confirmationDialog("Which system is this?", isPresented: $showingDisambiguation,
                             presenting: pendingChoice) { choice in
            ForEach(choice.candidates) { candidate in
                Button(candidate.displayName) {
                    library.importGame(from: choice.url, as: candidate.id)
                    advanceImportQueue()
                }
            }
            Button("Skip this file", role: .cancel) {
                advanceImportQueue()
            }
        } message: { choice in
            Text("\(choice.url.lastPathComponent) matches more than one system. Choose the one it's actually for.")
        }
        .fullScreenCover(item: $playing) { game in
            EmulationView(game: game)
        }
        .alert("Import", isPresented: .constant(library.lastError != nil)) {
            Button("OK") { library.lastError = nil }
        } message: {
            Text(library.lastError ?? "")
        }
    }

    /// Works through `importQueue` one file at a time. Most extensions name exactly one system and
    /// go straight to the library; a handful (a raw `.iso`, say — GameCube, PS2, and PSP all use it)
    /// name several, and guessing which one silently would sometimes just be wrong. Those pause here
    /// for `pendingChoice` and resume once the player answers.
    private func advanceImportQueue() {
        pendingChoice = nil
        guard !importQueue.isEmpty else { return }
        let url = importQueue.removeFirst()
        let candidates = SystemCatalog.profiles(forExtension: url.pathExtension)
        if candidates.count > 1 {
            pendingChoice = AmbiguousImport(url: url, candidates: candidates)
            showingDisambiguation = true
        } else {
            library.importGame(from: url)
            advanceImportQueue()
        }
    }
}

/// One picked file whose extension matches more than one system, waiting on the player to say
/// which. `id` is per-attempt so re-picking the same file after a "Skip" presents a fresh dialog.
private struct AmbiguousImport: Identifiable {
    let id = UUID()
    let url: URL
    let candidates: [SystemProfile]
}

private struct SectionHeader: View {
    let profile: SystemProfile

    var body: some View {
        HStack(spacing: 6) {
            Text(profile.displayName)
            if !profile.coreStatus.isAvailable {
                Text("no core yet")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .textCase(nil)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GameRow: View {
    let game: Game
    let profile: SystemProfile
    let play: () -> Void

    private var isPlayable: Bool { profile.coreStatus.isAvailable }

    var body: some View {
        Button(action: play) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title).foregroundStyle(.primary)
                    Text(profile.shortName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isPlayable ? "play.circle.fill" : "info.circle")
                    .imageScale(.large)
                    .foregroundStyle(isPlayable ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(game.title), \(profile.displayName)")
        .accessibilityValue(isPlayable ? "Ready to play" : "No core yet")
    }
}

private struct EmptyLibraryView: View {
    let importGames: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.largeTitle.weight(.light))
                .imageScale(.large)
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("No games yet")
                    .font(.title3.weight(.semibold))
                Text("Import a ROM you own. Avalon recognises it by its contents, not its filename.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            Button("Import a game", action: importGames)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// What Avalon supports, stated plainly. A system with no core says what it is waiting for rather
/// than sitting in a list implying it works.
struct SystemsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Playable now") {
                    ForEach(SystemCatalog.playable) { profile in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                            Text("." + profile.fileExtensions.joined(separator: ", ."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Recognised, no core yet") {
                    ForEach(SystemCatalog.all.filter { !$0.coreStatus.isAvailable }) { profile in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.displayName)
                            if case .notYet(let note) = profile.coreStatus {
                                Text(note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Systems")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
