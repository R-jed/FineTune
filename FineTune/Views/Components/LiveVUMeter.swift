import SwiftUI

/// Isolates high-frequency source-level sampling from the rest of an App row.
/// Only this small subtree invalidates at the VU refresh cadence.
struct LiveVUMeter: View {
    let isMuted: Bool
    let isActive: Bool
    let readLevel: () -> Float

    @State private var displayLevel: Float = 0
    @State private var levelTimer: Timer?

    var body: some View {
        VUMeter(level: displayLevel, isMuted: isMuted)
            .onAppear(perform: reconcilePolling)
            .onDisappear(perform: stopPolling)
            .onChange(of: isActive) { _, _ in
                reconcilePolling()
            }
    }

    private func reconcilePolling() {
        if isActive {
            startPolling()
        } else {
            stopPolling()
            displayLevel = 0
        }
    }

    private func startPolling() {
        guard levelTimer == nil else { return }
        levelTimer = Timer.scheduledTimer(
            withTimeInterval: DesignTokens.Timing.vuMeterUpdateInterval,
            repeats: true
        ) { _ in
            MainActor.assumeIsolated {
                displayLevel = readLevel()
            }
        }
    }

    private func stopPolling() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}
