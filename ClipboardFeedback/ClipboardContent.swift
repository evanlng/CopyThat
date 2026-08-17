import AppKit

enum ClipboardContentKind: String, CaseIterable, Identifiable {
    case link
    case phoneNumber
    case emailAddress
    case code
    case files
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .link: return "Link"
        case .phoneNumber: return "Phone Number"
        case .emailAddress: return "Email Address"
        case .code: return "Code"
        case .files: return "Files"
        case .image: return "Images"
        }
    }

    var subtitle: String { rawValue }

    var symbolName: String {
        switch self {
        case .link: return "link"
        case .phoneNumber: return "phone"
        case .emailAddress: return "envelope"
        case .code: return "curlybraces"
        case .files: return "folder"
        case .image: return "photo"
        }
    }
}

enum ClipboardContent: Equatable {
    case text(String)
    case link(URL)
    case phoneNumber(display: String, normalized: String)
    case emailAddress(String)
    case code(language: CodeLanguage, preview: String, source: String?)
    case files([URL], totalCount: Int)
    case image(thumbnail: ClipboardImagePreview?)
    case other

    var title: String {
        switch self {
        case .text:
            return "Copied"
        case .link:
            return "Link copied"
        case .phoneNumber:
            return "Phone number copied"
        case .emailAddress:
            return "Email copied"
        case .code:
            return "Code copied"
        case .files(_, let totalCount):
            return totalCount == 1 ? "File copied" : "\(totalCount) files copied"
        case .image:
            return "Image copied"
        case .other:
            return "Item copied"
        }
    }

    var preview: String? {
        switch self {
        case .text(let text):
            return TextPreview.make(text)
        case .link(let url):
            return URLDetector.displayString(for: url)
        case .phoneNumber(let display, _):
            return display
        case .emailAddress(let email):
            return email
        case .code(_, let preview, _):
            return preview
        case .files(let urls, let totalCount):
            let names = urls.prefix(2).map(\.lastPathComponent)
            let suffix = totalCount > 2 ? " +\(totalCount - 2) more" : ""
            return names.joined(separator: ", ") + suffix
        case .image(let thumbnail):
            return thumbnail == nil ? "Ready to paste" : nil
        case .other:
            return nil
        }
    }

    var symbolName: String {
        switch self {
        case .link:
            return "link"
        case .phoneNumber:
            return "phone.fill"
        case .emailAddress:
            return "envelope.fill"
        case .code:
            return "curlybraces"
        case .files:
            return "folder.fill"
        case .image:
            return "photo"
        case .text, .other:
            return "checkmark"
        }
    }

    var imagePreview: ClipboardImagePreview? {
        guard case .image(let thumbnail) = self else { return nil }
        return thumbnail
    }

    var languageLabel: String? {
        guard case .code(let language, _, _) = self else { return nil }
        return language.title
    }

    func primaryAction(
        using searchProvider: WebSearchProvider? = .duckDuckGo
    ) -> ClipboardActionDescriptor? {
        switch self {
        case .text(let text):
            guard let searchURL = searchProvider?.searchURL(for: text) else {
                return nil
            }
            return ClipboardActionDescriptor(
                title: "Search",
                systemImage: "magnifyingglass",
                target: .external(
                    .openInApplication(
                        urls: [searchURL],
                        bundleIdentifier: "com.apple.Safari"
                    )
                )
            )

        case .link(let url):
            return ClipboardActionDescriptor(
                title: "Open Safari",
                systemImage: "safari",
                target: .external(
                    .openInApplication(
                        urls: [url],
                        bundleIdentifier: "com.apple.Safari"
                    )
                )
            )

        case .phoneNumber(_, let normalized):
            guard let url = URL(string: "tel:\(normalized)") else { return nil }
            return ClipboardActionDescriptor(
                title: "Call",
                systemImage: "phone.fill",
                target: .external(.openDefault(url))
            )

        case .emailAddress(let email):
            guard let encoded = email.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ), let url = URL(string: "mailto:\(encoded)") else { return nil }
            return ClipboardActionDescriptor(
                title: "Compose",
                systemImage: "envelope.fill",
                target: .external(.openDefault(url))
            )

        case .code(let language, _, .some(let source))
            where language.supportsBasicFormatting:
            return ClipboardActionDescriptor(
                title: "Format",
                systemImage: "text.alignleft",
                target: .formatCode(language: language, source: source)
            )

        case .files(let urls, _) where !urls.isEmpty:
            return ClipboardActionDescriptor(
                title: "Show in Finder",
                systemImage: "folder",
                target: .external(.revealInFinder(urls))
            )

        case .code, .files, .image, .other:
            return nil
        }
    }
}

enum TextPreview {
    static func make(_ text: String, limit: Int = 110) -> String {
        let oneLine = text
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")

        guard oneLine.count > limit else { return oneLine }
        guard limit > 1 else { return "…" }
        return String(oneLine.prefix(limit - 1)) + "…"
    }
}
