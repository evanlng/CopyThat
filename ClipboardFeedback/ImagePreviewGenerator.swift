import AppKit
import ImageIO

struct ClipboardImagePreview: Equatable {
    let image: NSImage
    let pixelSize: CGSize
    let contentFingerprint: Int

    static func == (lhs: ClipboardImagePreview, rhs: ClipboardImagePreview) -> Bool {
        lhs.contentFingerprint == rhs.contentFingerprint
    }
}

/// Decodes only a small thumbnail from the pasteboard representation. The
/// original image data is scoped to this call and is never cached or written.
struct ImagePreviewGenerator {
    let maximumPixelDimension: Int

    init(maximumPixelDimension: Int = 240) {
        self.maximumPixelDimension = maximumPixelDimension
    }

    func makePreview(
        from pasteboard: NSPasteboard,
        type preferredType: NSPasteboard.PasteboardType? = nil
    ) -> ClipboardImagePreview? {
        autoreleasepool {
            guard maximumPixelDimension > 0,
                  let type = preferredType
                    ?? pasteboard.availableType(from: [.png, .tiff]),
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
                pixelSize: pixelSize,
                contentFingerprint: fingerprint(of: thumbnail)
            )
        }
    }

    private func fingerprint(of image: CGImage) -> Int {
        var hasher = Hasher()
        hasher.combine(image.width)
        hasher.combine(image.height)
        hasher.combine(image.bitsPerPixel)
        hasher.combine(image.bytesPerRow)
        if let data = image.dataProvider?.data,
           let bytes = CFDataGetBytePtr(data) {
            hasher.combine(bytes: UnsafeRawBufferPointer(
                start: bytes,
                count: CFDataGetLength(data)
            ))
        }
        return hasher.finalize()
    }
}
