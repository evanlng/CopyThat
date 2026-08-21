import AppKit
import Foundation
import JavaScriptCore
import UniformTypeIdentifiers

/// A versioned plugin manifest. Schema v1 remains a data-only HTTPS action.
/// Schema v2 may run bounded JavaScript after an explicit user click. The
/// script receives no system APIs except permission-checked Host API bridges.
struct DeclarativePluginManifest: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 2
    static let currentHostAPIVersion = 2
    static let maximumFileSize = 64 * 1_024
    static let maximumInstalledPlugins = 32
    static let maximumScriptCharacters = 32_000

    let schemaVersion: Int
    let identifier: String
    let name: LocalizedPluginText
    let description: LocalizedPluginText
    let systemImage: String
    let matches: [DeclarativePluginContentKind]
    let action: DeclarativePluginAction
    let minimumHostAPIVersion: Int?
    let permissions: [DeclarativePluginPermission]?
    let script: String?

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

    func actions(
        for content: ClipboardContent,
        locale: InterfaceLocale
    ) -> [ClipboardActionDescriptor] {
        guard let input = content.declarativePluginInput,
              matches(input) else {
            return []
        }

        switch action.type {
        case .openURL:
            guard let value = input.textValue,
                  let url = action.url(for: value) else { return [] }
            return [ClipboardActionDescriptor(
                title: action.title.value(in: locale),
                systemImage: resolvedSystemImage,
                target: .external(.openDefault(url))
            )]
        case .runScript:
            guard let script else { return [] }
            return [ClipboardActionDescriptor(
                title: action.title.value(in: locale),
                systemImage: resolvedSystemImage,
                target: .runPlugin(
                    PluginScriptInvocation(
                        identifier: identifier,
                        script: script,
                        permissions: Set(permissions ?? []),
                        content: input
                    )
                )
            )]
        }
    }

    func action(
        for content: ClipboardContent,
        locale: InterfaceLocale
    ) -> ClipboardActionDescriptor? {
        actions(for: content, locale: locale).first
    }

    private func matches(_ input: PluginContentInput) -> Bool {
        if input.kind == .imageFiles {
            return matches.contains(.files) || matches.contains(.imageFiles)
        }
        return matches.contains(input.kind)
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
    case files
    case imageFiles
    case image
    case other
}

enum DeclarativePluginPermission: String, Codable, CaseIterable, Hashable {
    case readText = "clipboard.readText"
    case readImage = "clipboard.readImage"
    case readFiles = "clipboard.readFiles"
    case writeText = "clipboard.writeText"
    case openApplication = "system.openApplication"
    case openHTTPS = "network.openHTTPS"

    func title(in locale: InterfaceLocale) -> String {
        switch self {
        case .readText:
            return L10n.text("Read copied text", "读取复制的文字", locale: locale)
        case .readImage:
            return L10n.text("Read the copied image", "读取复制的图片", locale: locale)
        case .readFiles:
            return L10n.text("Read copied Finder files", "读取从访达复制的文件", locale: locale)
        case .writeText:
            return L10n.text("Write text to the clipboard", "将文字写入剪贴板", locale: locale)
        case .openApplication:
            return L10n.text("Open an installed application", "打开已安装的应用", locale: locale)
        case .openHTTPS:
            return L10n.text("Open an HTTPS address", "打开 HTTPS 地址", locale: locale)
        }
    }
}

struct DeclarativePluginAction: Codable, Equatable {
    enum ActionType: String, Codable {
        case openURL
        case runScript
    }

    let type: ActionType
    let title: LocalizedPluginText
    let urlTemplate: String?

    func url(for content: String) -> URL? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 1_000,
              type == .openURL,
              let urlTemplate,
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
    case unsupportedHostAPI
    case invalidPermissions
    case invalidScript
    case invalidAction
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
        case .unsupportedHostAPI:
            return "This plugin requires a newer CopyThat Host API."
        case .invalidPermissions:
            return "The plugin contains invalid or duplicate permissions."
        case .invalidScript:
            return "The plugin script is missing or exceeds the 32,000-character limit."
        case .invalidAction:
            return "The plugin action is not valid for its schema version."
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
        guard (1...DeclarativePluginManifest.currentSchemaVersion)
            .contains(manifest.schemaVersion) else {
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

        if manifest.schemaVersion == 1 {
            guard manifest.action.type == .openURL,
                  manifest.minimumHostAPIVersion == nil,
                  manifest.permissions == nil,
                  manifest.script == nil,
                  !manifest.matches.contains(.files),
                  !manifest.matches.contains(.image),
                  !manifest.matches.contains(.other) else {
                throw DeclarativePluginValidationError.invalidAction
            }
        } else {
            guard manifest.action.type == .runScript,
                  let minimumHostAPIVersion = manifest.minimumHostAPIVersion,
                  (1...DeclarativePluginManifest.currentHostAPIVersion)
                    .contains(minimumHostAPIVersion) else {
                throw DeclarativePluginValidationError.unsupportedHostAPI
            }
            let permissions = manifest.permissions ?? []
            guard permissions.count <= DeclarativePluginPermission.allCases.count,
                  Set(permissions).count == permissions.count else {
                throw DeclarativePluginValidationError.invalidPermissions
            }
        }

        switch manifest.action.type {
        case .openURL:
            guard manifest.script == nil,
                  let template = manifest.action.urlTemplate,
                  template.count <= 2_048,
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
        case .runScript:
            guard manifest.schemaVersion >= 2,
                  manifest.action.urlTemplate == nil,
                  let script = manifest.script?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ),
                  !script.isEmpty,
                  script.count <= DeclarativePluginManifest.maximumScriptCharacters else {
                throw DeclarativePluginValidationError.invalidScript
            }
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

struct PluginContentInput: Equatable {
    let kind: DeclarativePluginContentKind
    let textValue: String?
    let fileURLs: [URL]
    let pasteboardChangeCount: Int?

    init(
        kind: DeclarativePluginContentKind,
        textValue: String?,
        fileURLs: [URL] = [],
        pasteboardChangeCount: Int? = nil
    ) {
        self.kind = kind
        self.textValue = textValue
        self.fileURLs = fileURLs
        self.pasteboardChangeCount = pasteboardChangeCount
    }
}

struct PluginScriptInvocation: Equatable {
    let identifier: String
    let script: String
    let permissions: Set<DeclarativePluginPermission>
    let content: PluginContentInput
}

private extension ClipboardContent {
    var declarativePluginInput: PluginContentInput? {
        switch self {
        case .text(let text):
            return PluginContentInput(kind: .text, textValue: text)
        case .calculation(_, let result):
            return PluginContentInput(kind: .calculation, textValue: result)
        case .englishWord(let word, _):
            return PluginContentInput(kind: .englishWord, textValue: word)
        case .chineseCharacter(let character, _, _):
            return PluginContentInput(kind: .chineseCharacter, textValue: character)
        case .link(let url):
            return PluginContentInput(kind: .link, textValue: url.absoluteString)
        case .phoneNumber(_, let normalized):
            return PluginContentInput(kind: .phoneNumber, textValue: normalized)
        case .emailAddress(let email):
            return PluginContentInput(kind: .emailAddress, textValue: email)
        case .code(_, let preview, let source):
            return PluginContentInput(kind: .code, textValue: source ?? preview)
        case .files(let urls, _):
            let kind: DeclarativePluginContentKind = urls.allSatisfy(isImageFile)
                ? .imageFiles
                : .files
            return PluginContentInput(kind: kind, textValue: nil, fileURLs: urls)
        case .image:
            return PluginContentInput(
                kind: .image,
                textValue: nil,
                pasteboardChangeCount: NSPasteboard.general.changeCount
            )
        case .other:
            return PluginContentInput(kind: .other, textValue: nil)
        }
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard url.isFileURL,
              let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }
}
