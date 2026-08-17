import AppKit
import XCTest
@testable import ClipboardFeedback

final class TextPreviewTests: XCTestCase {
    func testCollapsesWhitespaceAndNewlines() {
        XCTAssertEqual(
            TextPreview.make("first line\n\nsecond   line"),
            "first line second line"
        )
    }

    func testTruncatesLongContent() {
        let preview = TextPreview.make(String(repeating: "a", count: 20), limit: 10)
        XCTAssertEqual(preview, "aaaaaaaaa…")
        XCTAssertEqual(preview.count, 10)
    }

    func testClipboardTitles() {
        let first = URL(fileURLWithPath: "/tmp/one.txt")
        let second = URL(fileURLWithPath: "/tmp/two.txt")
        let third = URL(fileURLWithPath: "/tmp/three.txt")
        XCTAssertEqual(ClipboardContent.text("hello").title, "Copied")
        XCTAssertEqual(
            ClipboardContent.files([first], totalCount: 1).title,
            "File copied"
        )
        XCTAssertEqual(
            ClipboardContent.files(
                [first, second, third],
                totalCount: 3
            ).title,
            "3 files copied"
        )
    }

    func testMonitorUsesResponsiveAdaptiveIntervals() {
        let configuration = ClipboardMonitorConfiguration.responsive
        XCTAssertLessThanOrEqual(configuration.idleInterval, 0.25)
        XCTAssertLessThanOrEqual(configuration.activeInterval, 0.06)
        XCTAssertLessThanOrEqual(configuration.activeDuration, 0.9)
        XCTAssertEqual(configuration.activePollLimit, 15)
    }

    func testHUDIsExactlyCenteredInVisibleScreenFrame() {
        let frame = NSRect(x: 100, y: 40, width: 1_440, height: 860)
        let size = NSSize(width: 400, height: 100)

        let origin = HUDPositioning.origin(
            in: frame,
            panelSize: size,
            margin: 16
        )

        XCTAssertEqual(origin.x, 620)
        XCTAssertEqual(origin.y, 784)
        XCTAssertEqual(origin.x + size.width / 2, frame.midX)
    }

    func testGlassStylesSnapToThreeNativeModes() {
        let clear = GlassAppearanceMetrics(strength: -1)
        let balanced = GlassAppearanceMetrics(strength: 0.55)
        let strong = GlassAppearanceMetrics(strength: 2)

        XCTAssertEqual(clear.strength, 0)
        XCTAssertEqual(balanced.strength, 0.5)
        XCTAssertEqual(strong.strength, 1)
        XCTAssertEqual(clear.level, .clear)
        XCTAssertEqual(balanced.level, .balanced)
        XCTAssertEqual(strong.level, .strong)
        XCTAssertTrue(clear.usesClearGlass)
        XCTAssertFalse(balanced.usesClearGlass)
        XCTAssertFalse(strong.usesClearGlass)
        XCTAssertEqual(clear.nativeMaterial, .clear)
        XCTAssertEqual(balanced.nativeMaterial, .regular)
        XCTAssertEqual(strong.nativeMaterial, .regular)
        XCTAssertEqual(clear.label, "Clear")
        XCTAssertEqual(balanced.label, "Balanced")
        XCTAssertEqual(strong.label, "Strong")
        XCTAssertFalse(balanced.usesStrongTint)
        XCTAssertTrue(strong.usesStrongTint)
        XCTAssertGreaterThan(strong.nativeTintOpacity, balanced.nativeTintOpacity)
    }

    func testGlassSliderThumbAndLabelsShareExactPositions() {
        let width: CGFloat = 420
        let clearX = GlassStyleSliderGeometry.position(for: 0, width: width)
        let balancedX = GlassStyleSliderGeometry.position(for: 0.5, width: width)
        let strongX = GlassStyleSliderGeometry.position(for: 1, width: width)

        XCTAssertEqual(clearX, GlassStyleSliderGeometry.endpointInset)
        XCTAssertEqual(balancedX, width / 2)
        XCTAssertEqual(strongX, width - GlassStyleSliderGeometry.endpointInset)
        XCTAssertEqual(GlassStyleSliderGeometry.value(at: clearX, width: width), 0)
        XCTAssertEqual(GlassStyleSliderGeometry.value(at: balancedX, width: width), 0.5)
        XCTAssertEqual(GlassStyleSliderGeometry.value(at: strongX, width: width), 1)
    }
}
