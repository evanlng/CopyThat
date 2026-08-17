import AppKit
import XCTest
@testable import ClipboardFeedback

final class ClipboardContentTests: XCTestCase {
    func testOversizedTextSkipsSemanticDetectorsAndRetainsOnlyPreviewBound() {
        let detector = CountingContentDetector()
        let analyzer = ClipboardAnalyzer(
            registry: ClipboardDetectionRegistry(detectors: [detector])
        )
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("CopyThat.OversizedText.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        pasteboard.setString(
            String(repeating: "a", count: 25_000),
            forType: .string
        )

        let content = analyzer.analyze(pasteboard, enabledKinds: [.link])

        XCTAssertEqual(detector.callCount, 0)
        XCTAssertEqual(content.preview?.count, 110)
        if case .text(let retained) = content {
            XCTAssertEqual(retained.count, 1_000)
        } else {
            XCTFail("Expected oversized input to remain bounded plain text")
        }
    }

    func testReadsPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("hello clipboard", forType: .string)

        XCTAssertEqual(
            ClipboardAnalyzer().analyze(pasteboard),
            .text("hello clipboard")
        )
    }

    func testPrefersSemanticWebURLOverDisplayText() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.declareTypes([.URL, .string], owner: nil)
        pasteboard.setString("https://www.apple.com/mac/", forType: .URL)
        pasteboard.setString("Apple Mac", forType: .string)

        XCTAssertEqual(
            ClipboardAnalyzer().analyze(pasteboard),
            .link(URL(string: "https://www.apple.com/mac/")!)
        )
    }

    func testReadsFinderStyleFileURL() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects([
            URL(fileURLWithPath: "/tmp/example.txt") as NSURL
        ])

        XCTAssertEqual(
            ClipboardAnalyzer().analyze(pasteboard),
            .files([URL(fileURLWithPath: "/tmp/example.txt")], totalCount: 1)
        )
    }

    func testDetectsPhoneNumberAndCreatesCallAction() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("+86 138-0013-8000", forType: .string)

        let content = ClipboardAnalyzer().analyze(pasteboard)
        XCTAssertEqual(
            content,
            .phoneNumber(display: "+86 138-0013-8000", normalized: "+8613800138000")
        )
        XCTAssertEqual(content.primaryAction()?.title, "Call")
        XCTAssertEqual(
            content.primaryAction()?.target,
            .external(.openDefault(URL(string: "tel:+8613800138000")!))
        )
    }

    func testDetectsEmailAddressAndCreatesComposeAction() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("hello@example.com", forType: .string)

        let content = ClipboardAnalyzer().analyze(pasteboard)
        XCTAssertEqual(content, .emailAddress("hello@example.com"))
        XCTAssertEqual(content.primaryAction()?.title, "Compose")
    }

    func testDisabledDetectorFallsBackToPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("13800138000", forType: .string)

        let enabledKinds = Set(ClipboardContentKind.allCases).subtracting([.phoneNumber])
        XCTAssertEqual(
            ClipboardAnalyzer().analyze(pasteboard, enabledKinds: enabledKinds),
            .text("13800138000")
        )
    }

    func testRecognizesWWWAddressAsHTTPSLink() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("www.openai.com/research", forType: .string)

        XCTAssertEqual(
            ClipboardAnalyzer().analyze(pasteboard),
            .link(URL(string: "https://www.openai.com/research")!)
        )
    }

    func testPlainTextUsesDuckDuckGoByDefault() {
        let content = ClipboardContent.text("macOS 剪贴板 工具")
        guard let action = content.primaryAction() else {
            return XCTFail("Expected a search action")
        }

        XCTAssertEqual(action.title, "Search")
        guard case .external(
            .openInApplication(let urls, let bundleIdentifier)
        ) = action.target,
              let searchURL = urls.first,
              let components = URLComponents(
                url: searchURL,
                resolvingAgainstBaseURL: false
              ) else {
            return XCTFail("Expected a Safari URL action")
        }

        XCTAssertEqual(bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(components.host, "duckduckgo.com")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "q" })?.value,
            "macOS 剪贴板 工具"
        )
    }

    func testPlainTextUsesCustomSearchProvider() {
        let provider = WebSearchProvider(
            name: "Brave Search",
            urlTemplate: "https://search.brave.com/search?q={query}&source=clipboard"
        )
        let content = ClipboardContent.text("macOS 剪贴板")

        guard let action = content.primaryAction(using: provider),
              case .external(
                .openInApplication(let urls, let bundleIdentifier)
              ) = action.target,
              let searchURL = urls.first,
              let components = URLComponents(
                url: searchURL,
                resolvingAgainstBaseURL: false
              ) else {
            return XCTFail("Expected a custom Safari search action")
        }

        XCTAssertEqual(bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(components.host, "search.brave.com")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "q" })?.value,
            "macOS 剪贴板"
        )
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "source" })?.value,
            "clipboard"
        )
    }

    func testRejectsUnsafeOrMalformedCustomSearchTemplates() {
        let unsafe = WebSearchProvider(
            name: "Unsafe",
            urlTemplate: "file:///tmp/search?q={query}"
        )
        let missingPlaceholder = WebSearchProvider(
            name: "Missing",
            urlTemplate: "https://example.com/search?q=clipboard"
        )
        let pathPlaceholder = WebSearchProvider(
            name: "Path",
            urlTemplate: "https://example.com/search/{query}"
        )

        XCTAssertNil(unsafe.searchURL(for: "hello"))
        XCTAssertNil(missingPlaceholder.searchURL(for: "hello"))
        XCTAssertNil(pathPlaceholder.searchURL(for: "hello"))
    }

    func testAnalyzerBoundsRetainedPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 5_000), forType: .string)

        guard case .text(let retained) = ClipboardAnalyzer().analyze(pasteboard) else {
            return XCTFail("Expected plain text")
        }
        XCTAssertEqual(retained.count, 1_000)
    }

    func testPythonCodeCreatesManualFormatAction() {
        let source = "def greet(name):  \n    print(name)  \n"
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString(source, forType: .string)

        let content = ClipboardAnalyzer().analyze(pasteboard)
        guard case .code(let language, _, let retainedSource) = content else {
            return XCTFail("Expected code")
        }
        XCTAssertEqual(language, .python)
        XCTAssertEqual(retainedSource, source)
        XCTAssertEqual(content.primaryAction()?.title, "Format")
    }
}

private final class CountingContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.link
    private(set) var callCount = 0

    func detect(in text: String) -> ClipboardContent? {
        callCount += 1
        return nil
    }
}
