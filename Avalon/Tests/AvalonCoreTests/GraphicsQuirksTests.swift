import Testing
@testable import AvalonCore

@Test("Every quirk carries an explanation a reader can act on")
func quirksAreExplained() {
    for q in GraphicsQuirk.allCases {
        #expect(!q.explanation.isEmpty, "\(q) has no explanation")
    }
}

@Test("Baseline Apple quirks are those true of every Apple GPU")
func baseline() {
    let b = GraphicsQuirks.appleBaseline
    #expect(b.has(.tileBasedBarrierScope))
    #expect(b.has(.noDepth24Stencil8))
    #expect(b.has(.preferTileMemoryForDestinationRead))
    // Sandbox and MoltenVK issues are not universal, so they are not in the baseline.
    #expect(!b.has(.noPosixSharedMemory))
    #expect(!b.has(.moltenVKDuplicateVertexAttributes))
}

@Test("iOS 16 with MoltenVK collects the version and translation-layer quirks")
func ios16MoltenVK() {
    let q = GraphicsQuirks.iOS(version: 16, usingMoltenVK: true)
    #expect(q.has(.crossStageBufferBindingBroken))          // < iOS 17
    #expect(q.has(.moltenVKDuplicateVertexAttributes))
    #expect(q.has(.deprecatedMoltenVKSurfaceExtension))
    #expect(q.has(.noPosixSharedMemory))
    #expect(q.has(.tileBasedBarrierScope))                  // baseline still applies
}

@Test("iOS 17 native Metal drops the version and MoltenVK quirks")
func ios17Native() {
    let q = GraphicsQuirks.iOS(version: 17, usingMoltenVK: false)
    #expect(!q.has(.crossStageBufferBindingBroken))
    #expect(!q.has(.moltenVKDuplicateVertexAttributes))
    #expect(q.has(.noPosixSharedMemory))                    // sandbox is not version-dependent
}

@Test("The Simulator lacks framebuffer fetch that device hardware has")
func simulatorDiffers() {
    #expect(GraphicsQuirks.simulator.has(.noFramebufferFetchOnSimulator))
    #expect(!GraphicsQuirks.iOS(version: 17).has(.noFramebufferFetchOnSimulator))
}

@Test("A 16 KB host page needs sub-page write tracking for a 4 KB guest")
func subPageTracking() {
    // This is why MeloNX cannot use its fast host-mapped path on Apple silicon: the guest page is
    // hard-coded to 4 KB and the host page is 16 KB, so it falls back to host-tracked mode and has
    // to patch fault addresses in a generated signal handler.
    let apple = DeviceCapabilities(hostPageSize: 16384)
    #expect(apple.requiresSubPageWriteTracking(guestPageSize: 4096))
    #expect(!apple.requiresSubPageWriteTracking(guestPageSize: 16384))

    let older = DeviceCapabilities(hostPageSize: 4096)
    #expect(!older.requiresSubPageWriteTracking(guestPageSize: 4096))
}
