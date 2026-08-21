import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(
            settings.isEnabled
                ? t("Pause", "暂停")
                : t("Resume", "继续")
        ) {
            settings.isEnabled.toggle()
        }

        Button {
            SettingsWindowPresenter.shared.show {
                openSettings()
            }
        } label: {
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
            ?? "3.0.1"
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
    }
}

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private weak var settingsWindow: NSWindow?

    private init() {}

    func show(openSettings: () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsWindow {
            bringToFront(settingsWindow)
        } else {
            openSettings()
        }
    }

    func register(_ window: NSWindow) {
        settingsWindow = window
        bringToFront(window)
    }

    static func configure(_ window: NSWindow) {
        window.level = .normal
        window.hidesOnDeactivate = false
    }

    private func bringToFront(_ window: NSWindow) {
        Self.configure(window)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
