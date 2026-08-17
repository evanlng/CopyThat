import AppKit
import SwiftUI

@MainActor
final class CodeFormatterWindowManager: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(language: CodeLanguage, source: String) {
        window?.close()

        let result = CodeFormatter.format(source, language: language)
        let view = CodeFormatterView(
            language: language,
            result: result,
            copyFormatted: { [weak self] formatted in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(formatted, forType: .string)
                self?.window?.close()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Format \(language.title)"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.setFrameAutosaveName("CodeFormatterWindow")
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

private struct CodeFormatterView: View {
    let language: CodeLanguage
    let result: Result<String, CodeFormattingError>
    let copyFormatted: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Formatted \(language.title)", systemImage: "curlybraces")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Review before copying")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch result {
            case .success(let formatted):
                ScrollView([.horizontal, .vertical]) {
                    Text(formatted)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(14)
                }
                .background(
                    Color(nsColor: .textBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.separator.opacity(0.7), lineWidth: 0.5)
                }

                HStack {
                    Text("Nothing is copied until you click the button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy formatted") {
                        copyFormatted(formatted)
                    }
                    .keyboardShortcut(.defaultAction)
                }

            case .failure(let error):
                ContentUnavailableView(
                    "Could Not Format Code",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .padding(22)
        .frame(minWidth: 560, minHeight: 380)
    }
}
