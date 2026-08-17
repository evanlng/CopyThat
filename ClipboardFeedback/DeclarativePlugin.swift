import AppKit
import Foundation

/// A small, data-only plugin format. Imported plugins can contribute one HTTPS
/// action, but cannot load code, start a service, or inspect the clipboard.
struct DeclarativePluginManifest: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1
    static let maximumFileSize = 64 * 1_024
    static let maximumInstalledPlugins = 32

    let schemaVersion: Int
    let identifier: String
    let name: LocalizedPluginText
    let description: LocalizedPluginText
    let systemImage: String
    let matches: [DeclarativePluginContentKind]
    let action: DeclarativePluginAction

    var id: String { identifier }

    func displayName(in locale: InterfaceLocale) -> String {
        name.value(in: locale)
    }

    func displayDescription(in locale: InterfaceLocale) -> String {
        description.value(in: locale)
    }

    var resolvedSystemImage: String {
        NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) == nil
            ? "puzzlepiece.extension"
            : systemImage
    }

    func action(
        for content: ClipboardContent,
        locale: InterfaceLocale
    ) -> ClipboardActionDescriptor? {
        guard let input = content.declarativePluginInput,
              matches.contains(input.kind),
              let url = action.url(for: input.value) else {
            return nil
        }

        return ClipboardActionDescriptor(
            title: action.title.value(in: locale),
            systemImage: resolvedSystemImage,
            target: .external(.openDefault(url))
        )
    }
}

struct LocalizedPluginText: Codable, Equatable {
    let english: String
    let simplifiedChinese: String?

    private enum CodingKeys: String, CodingKey {
        case english = "en"
        case simplifiedChinese = "zh-Hans"
    }

    func value(in locale: InterfaceLocale) -> String {
        if locale == .simplifiedChinese,
           let simplifiedChinese,
           !simplifiedChinese.isEmpty {
            return simplifiedChinese
        }
        return english
    }
}

enum DeclarativePluginContentKind: String, Codable, CaseIterable {
    case text
    case calculation
    case englishWord
    case chineseCharacter
    case link
    case phoneNumber
    case emailAddress
    case code
}

struct DeclarativePluginAction: Codable, Equatable {
    enum ActionType: String, Codable {
        case openURL
    }

    let type: ActionType
    let title: LocalizedPluginText
    let urlTemplate: String

    func url(for content: String) -> URL? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 1_000,
              type == .openURL,
              var components = URLComponents(string: urlTemplate),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              let queryItems = components.queryItems else {
            return nil
        }

        let placeholderItems = queryItems.filter {
            $0.value?.contains("{content}") == true
        }
        guard placeholderItems.count == 1 else { return nil }

        components.scheme = "https"
        components.queryItems = queryItems.map { item in
            URLQueryItem(
                name: item.name,
                value: item.value?.replacingOccurrences(
                    of: "{content}",
                    with: trimmed
                )
            )
        }
        return components.url
    }
}

enum DeclarativePluginValidationError: LocalizedError, Equatable {
    case fileTooLarge
    case invalidJSON
    case unsupportedVersion
    case invalidIdentifier
    case invalidText
    case invalidSymbol
    case invalidMatches
    case unsafeURLTemplate
    case tooManyPlugins

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "The plugin file is larger than 64 KB."
        case .invalidJSON:
            return "The plugin manifest is not valid JSON."
        case .unsupportedVersion:
            return "This plugin format version is not supported."
        case .invalidIdentifier:
            return "The plugin identifier must use reverse-domain format."
        case .invalidText:
            return "The plugin name, description, or button title is invalid."
        case .invalidSymbol:
            return "The plugin icon name is invalid."
        case .invalidMatches:
            return "The plugin must select between one and four supported content types."
        case .unsafeURLTemplate:
            return "The action must be an HTTPS URL with one {content} placeholder in a query value."
        case .tooManyPlugins:
            return "CopyThat supports up to 32 imported plugins."
        }
    }
}

enum DeclarativePluginCodec {
    private static let identifierExpression = try! NSRegularExpression(
        pattern: #"^[A-Za-z0-9][A-Za-z0-9-]*(?:\.[A-Za-z0-9][A-Za-z0-9-]*)+$"#
    )

    static func decodeAndValidate(_ data: Data) throws -> DeclarativePluginManifest {
        guard data.count <= DeclarativePluginManifest.maximumFileSize else {
            throw DeclarativePluginValidationError.fileTooLarge
        }

        let manifest: DeclarativePluginManifest
        do {
            manifest = try JSONDecoder().decode(DeclarativePluginManifest.self, from: data)
        } catch {
            throw DeclarativePluginValidationError.invalidJSON
        }
        try validate(manifest)
        return manifest
    }

    static func encoded(_ manifest: DeclarativePluginManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(manifest)
    }

    private static func validate(_ manifest: DeclarativePluginManifest) throws {
        guard manifest.schemaVersion == DeclarativePluginManifest.currentSchemaVersion else {
            throw DeclarativePluginValidationError.unsupportedVersion
        }

        let identifierRange = NSRange(
            manifest.identifier.startIndex..<manifest.identifier.endIndex,
            in: manifest.identifier
        )
        guard manifest.identifier.count <= 120,
              Self.identifierExpression.firstMatch(
                in: manifest.identifier,
                range: identifierRange
              )?.range == identifierRange else {
            throw DeclarativePluginValidationError.invalidIdentifier
        }

        guard valid(manifest.name, maximumLength: 60),
              valid(manifest.description, maximumLength: 240),
              valid(manifest.action.title, maximumLength: 40) else {
            throw DeclarativePluginValidationError.invalidText
        }

        let symbolCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: ".")
        )
        guard !manifest.systemImage.isEmpty,
              manifest.systemImage.count <= 80,
              manifest.systemImage.unicodeScalars.allSatisfy(symbolCharacters.contains) else {
            throw DeclarativePluginValidationError.invalidSymbol
        }

        guard (1...4).contains(manifest.matches.count),
              Set(manifest.matches).count == manifest.matches.count else {
            throw DeclarativePluginValidationError.invalidMatches
        }

        let template = manifest.action.urlTemplate
        guard template.count <= 2_048,
              template.components(separatedBy: "{content}").count == 2,
              let components = URLComponents(string: template),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              !components.path.contains("{content}"),
              components.host?.contains("{content}") == false,
              components.fragment?.contains("{content}") != true,
              manifest.action.url(for: "validation") != nil else {
            throw DeclarativePluginValidationError.unsafeURLTemplate
        }
    }

    private static func valid(
        _ text: LocalizedPluginText,
        maximumLength: Int
    ) -> Bool {
        let english = text.english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !english.isEmpty, english.count <= maximumLength else { return false }
        if let chinese = text.simplifiedChinese {
            let trimmed = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= maximumLength else { return false }
        }
        return true
    }
}

private extension ClipboardContent {
    var declarativePluginInput: (kind: DeclarativePluginContentKind, value: String)? {
        switch self {
        case .text(let text):
            return (.text, text)
        case .calculation(_, let result):
            return (.calculation, result)
        case .englishWord(let word, _):
            return (.englishWord, word)
        case .chineseCharacter(let character, _, _):
            return (.chineseCharacter, character)
        case .link(let url):
            return (.link, url.absoluteString)
        case .phoneNumber(_, let normalized):
            return (.phoneNumber, normalized)
        case .emailAddress(let email):
            return (.emailAddress, email)
        case .code(_, let preview, let source):
            return (.code, source ?? preview)
        case .files, .image, .other:
            return nil
        }
    }
}
