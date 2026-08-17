import SwiftUI

@main
struct ClipboardFeedbackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsManager.shared

    var body: some Scene {
        MenuBarExtra("CopyThat", systemImage: "doc.on.clipboard") {
            MenuBarView(settings: settings)
        }

        Settings {
            ClipboardFeedbackSettingsView(settings: settings)
        }
    }
}

extension Bundle {
    var copyThatDisplayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "CopyThat"
    }
}
