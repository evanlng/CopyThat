import AppKit
import SwiftUI

@MainActor
final class PluginReferenceWindowManager: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(_ reference: ClipboardReference) {
        window?.close()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Character Details"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: PluginReferenceView(reference: reference)
        )
        window.center()
        window.setFrameAutosaveName("PluginReferenceWindow")
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        closingWindow.contentView = nil
        window = nil
    }
}

private struct PluginReferenceView: View {
    let reference: ClipboardReference

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(reference.title)
                    .font(.system(size: 54, weight: .medium))
                Text(reference.subtitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                Text(reference.body)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 230)
    }
}
