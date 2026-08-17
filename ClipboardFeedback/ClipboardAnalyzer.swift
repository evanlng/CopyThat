import AppKit

/// Performs one bounded, local inspection after the monitor observes a new
/// pasteboard changeCount. Returned data lives only as long as its HUD/window.
struct ClipboardAnalyzer {
    private static let maximumAnalysisCharacters = 20_000
    private static let retainedTextLimit = 1_000
    private static let retainedFileLimit = 20
    private static let filePasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        NSPasteboard.PasteboardType("NSFilenamesPboardType")
    ]

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
           pasteboard.availableType(from: Self.filePasteboardTypes) != nil,
           let fileContent = fileContent(from: pasteboard) {
            return fileContent
        }

        if enabledKinds.contains(.image),
           let imageType = pasteboard.availableType(from: [.png, .tiff]) {
            return .image(
                thumbnail: imagePreviewGenerator.makePreview(
                    from: pasteboard,
                    type: imageType
                )
            )
        }

        if enabledKinds.contains(.link),
           let rawURL = pasteboard.string(forType: .URL),
           let url = URLDetector.webURL(from: rawURL) {
            return .link(url)
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // Never let a multi-megabyte paste make every detector traverse the
            // full value. Oversized content remains ordinary text feedback.
            let isOversized = text.index(
                text.startIndex,
                offsetBy: Self.maximumAnalysisCharacters + 1,
                limitedBy: text.endIndex
            ) != nil
            if !isOversized,
               let detection = registry.detect(in: text, enabledKinds: enabledKinds) {
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
