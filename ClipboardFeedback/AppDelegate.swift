import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlayManager = OverlayManager()
    private var enabledCancellable: AnyCancellable?

    private lazy var clipboardMonitor = ClipboardMonitor(
        enabledKindsProvider: {
            SettingsManager.shared.enabledDetectionKinds
        }
    ) { [weak self] content in
        guard SettingsManager.shared.isEnabled else { return }
        self?.overlayManager.show(content)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        enabledCancellable = SettingsManager.shared.$isEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled {
                    self?.clipboardMonitor.start()
                } else {
                    self?.clipboardMonitor.stop()
                    self?.overlayManager.dismiss()
                }
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }
}
