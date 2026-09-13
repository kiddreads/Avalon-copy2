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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var emulator = Emulator()
    @State private var router: TouchRouter?
    @State private var pressed: Set<String> = []
    /// Which combination of directions is currently active per d-pad control id (e.g. "up+right"),
    /// so `ControlsView` can tell a genuine new direction from the same one still held.
    @State private var directions: [String: String] = [:]
    @State private var mode: ViewMode = .windowed
    @State private var showMenu = false
    @State private var showCloseConfirmation = false
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

                ControlsView(layout: layout, pressed: pressed, directions: directions)

                TouchSurface { touches in
                    guard let router else { return }
                    let events = router.process(touches: touches)
                    if !events.isEmpty { emulator.send(events) }
                    pressed = Set(layout.controls.compactMap { control in
                        control.source.bindings.contains { router.value(of: $0.control) != 0 }
                            ? control.id : nil
                    })
                    // Only the d-pad needs finer detail than "held or not": a haptic tap on
                    // direction change has to tell "still pointing up" from "now up-right", which
                    // the plain `pressed` set above can't, since it only tracks the control's id.
                    directions = Dictionary(uniqueKeysWithValues: layout.controls
                        .filter { $0.kind == .dpad }
                        .map { control in
                            let active = control.source.bindings
                                .filter { router.value(of: $0.control) != 0 }
                                .map { "\($0.control)" }
                                .sorted()
                                .joined(separator: "+")
                            return (control.id, active)
                        })
                }
                .ignoresSafeArea()

                menuButton
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: mode)
            .onAppear {
                router = TouchRouter(layout: layout)
                if playable { emulator.start(game: game) }
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
                    .antialiased(false)             // no edge smoothing at fractional scales either
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
        // No explicit safe-area handling needed here: this button lives inside the same
        // GeometryReader `bounds` the layout solver uses, and only `Color.black` and
        // `TouchSurface` opt out of the safe area above — the reader itself does not, so its
        // origin already sits inside the safe area on every device profile (notch, Dynamic
        // Island, and the home indicator alike). The padding below is just breathing room on
        // top of that, not a substitute for it.
        Button { showMenu = true } label: {
            Image(systemName: "chevron.left.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.leading, 10)
        .padding(.top, 8)
        .accessibilityLabel("Menu")
        .accessibilityHint("Pause and show display, controls and game options")
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

                Section {
                    Picker("Layout", selection: $layoutID) {
                        ForEach((try? TouchLayoutLibrary.builtIn())?.layouts ?? [], id: \.id) { l in
                            // One `Text`, two styles: the platform name reads first and heaviest,
                            // the hardware name follows as a caption — legible at a glance instead
                            // of one long undifferentiated run of "Name — Hardware".
                            (Text(l.name)
                                + Text("  ·  \(l.hardware)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary))
                                .tag(l.id)
                        }
                    }
                } header: {
                    Text("Controls")
                } footer: {
                    Text("Each layout is that system's real controller, resized to fit your screen.")
                }

                Section("Game") {
                    LabeledContent("Title", value: game.title)
                    LabeledContent("System", value: game.profile?.displayName ?? "Unknown")
                    LabeledContent("SHA-1", value: String(game.id.prefix(12)))
                }

                Section {
                    Button("Close Game", role: .destructive) {
                        showCloseConfirmation = true
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
            .confirmationDialog("Close this game?",
                                isPresented: $showCloseConfirmation,
                                titleVisibility: .visible) {
                Button("Close Game", role: .destructive) {
                    showMenu = false
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The game stops running immediately.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
