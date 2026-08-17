import AppKit
import ImageIO

struct ClipboardImagePreview: Equatable {
    let image: NSImage
    let pixelSize: CGSize

    static func == (lhs: ClipboardImagePreview, rhs: ClipboardImagePreview) -> Bool {
        lhs.pixelSize == rhs.pixelSize
    }
}

/// Decodes only a small thumbnail from the pasteboard representation. The
/// original image data is scoped to this call and is never cached or written.
struct ImagePreviewGenerator {
    let maximumPixelDimension: Int

    init(maximumPixelDimension: Int = 240) {
        self.maximumPixelDimension = maximumPixelDimension
    }

    func makePreview(from pasteboard: NSPasteboard) -> ClipboardImagePreview? {
        autoreleasepool {
            guard maximumPixelDimension > 0,
                  let type = pasteboard.availableType(from: [.png, .tiff]),
                  let data = pasteboard.data(forType: type),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            ) else {
                return nil
            }

            let pixelSize = CGSize(width: thumbnail.width, height: thumbnail.height)
            return ClipboardImagePreview(
                image: NSImage(cgImage: thumbnail, size: pixelSize),
                pixelSize: pixelSize
            )
        }
    }
}
