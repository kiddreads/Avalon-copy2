// Avalon — playing.
//
// The layout is solved for the actual screen this is running on, every frame it changes size.
// Nothing about the arrangement is decided here: `LayoutSolver` places the controls and the game
// rect, `LayoutVerifier` has already proved that arrangement is sound on this device class, and
// `TouchRouter` turns fingers into input events. This view draws and forwards.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SwiftUI
import AvalonCore

struct EmulationView: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @StateObject private var emulator = Emulator()
    @State private var router: TouchRouter?
    @State private var pressed: Set<String> = []
    @State private var mode: ViewMode = .windowed
    @State private var showMenu = false
    @State private var layoutID: String

    init(game: Game) {
        self.game = game
        _layoutID = State(initialValue: game.profile?.layoutID ?? "nes")
    }

    private var playable: Bool { game.profile?.coreStatus.isAvailable == true }

    var body: some View {
        GeometryReader { geo in
            let bounds = LayoutRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height)
            let layout = LayoutSolver.solve(touchLayout, in: bounds, mode: mode)

            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                screen(in: layout)

                ControlsView(layout: layout, pressed: pressed)

                TouchSurface { touches in
                    guard let router else { return }
                    let events = router.process(touches: touches)
                    if !events.isEmpty { emulator.send(events) }
                    pressed = Set(layout.controls.compactMap { control in
                        control.source.bindings.contains { router.value(of: $0.control) != 0 }
                            ? control.id : nil
                    })
                }
                .ignoresSafeArea()

                menuButton
            }
            .onAppear {
                router = TouchRouter(layout: layout)
                if playable { emulator.start() }
            }
            .onChange(of: geo.size) { _ in
                // A rotation or a split-view resize re-solves the layout, and anything held is
                // released first so a control that moved out from under a finger cannot stick.
                let resolved = LayoutSolver.solve(touchLayout, in: bounds, mode: mode)
                if let router { emulator.send(router.update(layout: resolved)) }
            }
            .onChange(of: mode) { _ in
                let resolved = LayoutSolver.solve(touchLayout, in: bounds, mode: mode)
                if let router { emulator.send(router.update(layout: resolved)) }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onDisappear { emulator.stop() }
        .sheet(isPresented: $showMenu) { menu }
    }

    private var touchLayout: TouchLayout {
        (try? TouchLayoutLibrary.builtIn())?.layout(id: layoutID)
            ?? (try! TouchLayoutLibrary.builtIn()).layouts[0]
    }

    @ViewBuilder
    private func screen(in layout: ResolvedLayout) -> some View {
        ZStack {
            Rectangle().fill(.black)
            if let frame = emulator.frame {
                Image(decorative: frame, scale: 1, orientation: .up)
                    .interpolation(.none)          // integer-ish scaling; no blurred pixels
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if !playable {
                unavailableNotice
            }
        }
        .frame(width: layout.gameRect.width, height: layout.gameRect.height)
        .clipped()
        .position(x: layout.gameRect.centre.x, y: layout.gameRect.centre.y)
    }

    private var unavailableNotice: some View {
        VStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.title2).foregroundStyle(.secondary)
            Text("No core for \(game.profile?.shortName ?? "this system") yet")
                .font(.callout.weight(.semibold))
            if case .notYet(let note) = game.profile?.coreStatus {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
            Text("The controls below are live — they are this system's real layout.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var menuButton: some View {
        Button { showMenu = true } label: {
            Image(systemName: "chevron.left.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.leading, 10)
        .padding(.top, 8)
    }

    private var menu: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Screen", selection: $mode) {
                        Text("Windowed").tag(ViewMode.windowed)
                        Text("Fullscreen").tag(ViewMode.fullscreen)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Fullscreen hands the whole screen to the game; the controls float over it.")
                }

                Section("Controls") {
                    Picker("Layout", selection: $layoutID) {
                        ForEach((try? TouchLayoutLibrary.builtIn())?.layouts ?? [], id: \.id) { l in
                            Text("\(l.name) — \(l.hardware)").tag(l.id)
                        }
                    }
                }

                Section("Game") {
                    LabeledContent("Title", value: game.title)
                    LabeledContent("System", value: game.profile?.displayName ?? "Unknown")
                    LabeledContent("SHA-1", value: String(game.id.prefix(12)))
                }

                Section {
                    Button("Close game", role: .destructive) {
                        showMenu = false
                        dismiss()
                    }
                }
            }
            .navigationTitle(game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Resume") { showMenu = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
