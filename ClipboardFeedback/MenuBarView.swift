import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Button(
            settings.isEnabled
                ? t("Pause", "暂停")
                : t("Resume", "继续")
        ) {
            settings.isEnabled.toggle()
        }

        SettingsLink {
            Label(t("Settings…", "设置…"), systemImage: "gearshape")
        }

        Text(t("Version \(appVersion)", "版本 \(appVersion)"))

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Text(t(
                "Quit \(Bundle.main.copyThatDisplayName(in: .english))",
                "退出 \(Bundle.main.copyThatDisplayName(in: settings.resolvedLocale))"
            ))
        }
        .keyboardShortcut("q")
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.1.0"
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
    }
}
