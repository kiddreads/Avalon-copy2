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
                for url in urls { library.importGame(from: url) }
            }
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
    }
}

private struct GameRow: View {
    let game: Game
    let profile: SystemProfile
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title).foregroundStyle(.primary)
                    Text(profile.shortName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: profile.coreStatus.isAvailable ? "play.circle.fill" : "info.circle")
                    .foregroundStyle(profile.coreStatus.isAvailable ? Color.accentColor : .secondary)
            }
        }
    }
}

private struct EmptyLibraryView: View {
    let importGames: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No games yet").font(.title3.weight(.semibold))
            Text("Import a ROM you own. Avalon recognises it by its contents, not its filename.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Import a game", action: importGames)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding()
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
