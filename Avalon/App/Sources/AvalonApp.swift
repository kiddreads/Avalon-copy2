// Avalon — the iOS app.
//
// Deliberately small. Its job is to prove the platform layer end to end on a real device: a core
// running through `CoreSession`, its frames arriving through `FramePresenter`, and the touch
// layouts driving it through `TouchRouter`. Everything it draws comes from AvalonCore; the app
// itself holds no emulation, no geometry and no input logic of its own.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SwiftUI
import AvalonCore

@main
struct AvalonApp: App {
    var body: some Scene {
        WindowGroup {
            // Status bar and system overlays are hidden by EmulationView itself, for the
            // immersive gameplay screen only. Applying it here at the scene root also hid the
            // clock, battery and Dynamic Island while just browsing the library, which is not
            // an immersive context and has no reason to suppress that system chrome.
            ContentView()
        }
    }
}
