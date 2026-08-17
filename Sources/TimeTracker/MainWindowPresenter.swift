import AppKit

@MainActor
enum MainWindowPresenter {
    private static let windowTitle = "Time Tracker"

    static func bringToFront(retriesRemaining: Int = 5) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: isMainWindow) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        guard retriesRemaining > 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            bringToFront(retriesRemaining: retriesRemaining - 1)
        }
    }

    private static func isMainWindow(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && window.title == windowTitle
    }
}
