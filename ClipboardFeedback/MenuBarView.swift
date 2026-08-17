import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Button(settings.isEnabled ? "Pause" : "Resume") {
            settings.isEnabled.toggle()
        }

        SettingsLink {
            Label("Settings…", systemImage: "gearshape")
        }

        Text("Version \(appVersion)")

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Text("Quit \(Bundle.main.copyThatDisplayName)")
        }
        .keyboardShortcut("q")
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.5.0"
    }
}
