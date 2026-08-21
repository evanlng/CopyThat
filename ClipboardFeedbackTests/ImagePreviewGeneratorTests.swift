import AppKit
import XCTest
@testable import ClipboardFeedback

final class ImagePreviewGeneratorTests: XCTestCase {
    func testCreatesBoundedThumbnailWithoutWritingAFile() {
        let image = NSImage(size: NSSize(width: 800, height: 400))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 800, height: 400).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation else {
            return XCTFail("Could not encode test image")
        }
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)

        let preview = ImagePreviewGenerator(maximumPixelDimension: 120)
            .makePreview(from: pasteboard)

        XCTAssertNotNil(preview)
        XCTAssertLessThanOrEqual(preview?.pixelSize.width ?? .infinity, 120)
        XCTAssertLessThanOrEqual(preview?.pixelSize.height ?? .infinity, 120)

        guard let preview else { return }
        var gate = ClipboardChangeGate()
        gate.reset(to: .image(thumbnail: preview))
        XCTAssertFalse(gate.shouldNotify(for: .image(thumbnail: preview)))
    }
}
