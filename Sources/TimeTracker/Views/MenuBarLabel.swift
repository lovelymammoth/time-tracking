import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: DataStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.isRunning ? "timer" : "clock")
            if store.isRunning, let start = store.runningStart {
                Text(elapsedString(from: start, to: now))
                    .monospacedDigit()
            }
        }
        .onReceive(timer) { date in now = date }
    }

    private func elapsedString(from start: Date, to now: Date) -> String {
        let interval = max(0, Int(now.timeIntervalSince(start)))
        let h = interval / 3600
        let m = (interval % 3600) / 60
        let s = interval % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
