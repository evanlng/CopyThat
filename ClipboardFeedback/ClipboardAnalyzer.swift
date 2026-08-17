import AppKit

/// Performs one bounded, local inspection after the monitor observes a new
/// pasteboard changeCount. Returned data lives only as long as its HUD/window.
struct ClipboardAnalyzer {
    private static let retainedTextLimit = 1_000
    private static let retainedFileLimit = 20

    let registry: ClipboardDetectionRegistry
    let imagePreviewGenerator: ImagePreviewGenerator

    init(
        registry: ClipboardDetectionRegistry = .builtIn,
        imagePreviewGenerator: ImagePreviewGenerator = ImagePreviewGenerator()
    ) {
        self.registry = registry
        self.imagePreviewGenerator = imagePreviewGenerator
    }

    func analyze(
        _ pasteboard: NSPasteboard,
        enabledKinds: Set<ClipboardContentKind> = Set(ClipboardContentKind.allCases)
    ) -> ClipboardContent {
        if enabledKinds.contains(.files),
           let fileContent = fileContent(from: pasteboard) {
            return fileContent
        }

        if enabledKinds.contains(.image),
           pasteboard.availableType(from: [.png, .tiff]) != nil {
            return .image(thumbnail: imagePreviewGenerator.makePreview(from: pasteboard))
        }

        if enabledKinds.contains(.link),
           let rawURL = pasteboard.string(forType: .URL),
           let url = URLDetector.webURL(from: rawURL) {
            return .link(url)
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            if let detection = registry.detect(in: text, enabledKinds: enabledKinds) {
                return detection
            }
            return .text(String(text.prefix(Self.retainedTextLimit)))
        }

        return .other
    }

    private func fileContent(from pasteboard: NSPasteboard) -> ClipboardContent? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urls = pasteboard
            .readObjects(forClasses: [NSURL.self], options: options)?
            .compactMap { ($0 as? NSURL)?.absoluteURL } ?? []
        guard !urls.isEmpty else { return nil }
        return .files(
            Array(urls.prefix(Self.retainedFileLimit)),
            totalCount: urls.count
        )
    }
}
