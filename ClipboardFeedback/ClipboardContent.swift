import AppKit

enum ClipboardContentKind: String, CaseIterable, Identifiable {
    case calculation
    case englishWord
    case chineseCharacter
    case link
    case phoneNumber
    case emailAddress
    case code
    case files
    case image

    var id: String { rawValue }

    var title: String {
        title(in: .english)
    }

    func title(in locale: InterfaceLocale) -> String {
        switch self {
        case .calculation: return L10n.text("Calculator", "计算器", locale: locale)
        case .englishWord: return L10n.text("English Dictionary", "英文词典", locale: locale)
        case .chineseCharacter: return L10n.text("Chinese Character", "汉字释义", locale: locale)
        case .link: return L10n.text("Link", "链接", locale: locale)
        case .phoneNumber: return L10n.text("Phone Number", "电话号码", locale: locale)
        case .emailAddress: return L10n.text("Email Address", "电子邮箱", locale: locale)
        case .code: return L10n.text("Code", "代码", locale: locale)
        case .files: return L10n.text("Files", "文件", locale: locale)
        case .image: return L10n.text("Images", "图片", locale: locale)
        }
    }

    func detail(in locale: InterfaceLocale) -> String {
        switch self {
        case .calculation:
            return L10n.text("Calculate bounded expressions locally.", "在本地计算有限长度的数学表达式。", locale: locale)
        case .englishWord:
            return L10n.text("Show English and Chinese word meanings.", "显示英文释义和中文词义。", locale: locale)
        case .chineseCharacter:
            return L10n.text("Show pinyin and a local definition.", "显示拼音和本地词典释义。", locale: locale)
        case .link:
            return L10n.text("Recognize web links, including www. addresses.", "识别网页链接，包括 www. 地址。", locale: locale)
        case .phoneNumber:
            return L10n.text("Recognize callable phone numbers.", "识别可以拨打的电话号码。", locale: locale)
        case .emailAddress:
            return L10n.text("Recognize email recipients.", "识别电子邮件收件人。", locale: locale)
        case .code:
            return L10n.text("Recognize supported code with local rules.", "使用本地规则识别支持的代码。", locale: locale)
        case .files:
            return L10n.text("Recognize copied Finder files.", "识别从访达复制的文件。", locale: locale)
        case .image:
            return L10n.text("Show a temporary image thumbnail.", "显示临时图片缩略图。", locale: locale)
        }
    }

    var symbolName: String {
        switch self {
        case .calculation: return "function"
        case .englishWord: return "character.book.closed"
        case .chineseCharacter: return "character.textbox"
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
    case calculation(expression: String, result: String)
    case englishWord(word: String, definition: String)
    case chineseCharacter(character: String, pinyin: String, definition: String?)
    case link(URL)
    case phoneNumber(display: String, normalized: String)
    case emailAddress(String)
    case code(language: CodeLanguage, preview: String, source: String?)
    case files([URL], totalCount: Int)
    case image(thumbnail: ClipboardImagePreview?)
    case other

    var title: String {
        title(in: .english)
    }

    func title(in locale: InterfaceLocale) -> String {
        switch self {
        case .text:
            return L10n.text("Copied", "已复制", locale: locale)
        case .calculation:
            return L10n.text("Calculated", "计算完成", locale: locale)
        case .englishWord:
            return L10n.text("Word found", "已找到单词", locale: locale)
        case .chineseCharacter:
            return L10n.text("Chinese character copied", "已复制汉字", locale: locale)
        case .link:
            return L10n.text("Link copied", "链接已复制", locale: locale)
        case .phoneNumber:
            return L10n.text("Phone number copied", "电话号码已复制", locale: locale)
        case .emailAddress:
            return L10n.text("Email copied", "邮箱已复制", locale: locale)
        case .code:
            return L10n.text("Code copied", "代码已复制", locale: locale)
        case .files(_, let totalCount):
            if totalCount == 1 {
                return L10n.text("File copied", "文件已复制", locale: locale)
            }
            return L10n.text(
                "\(totalCount) files copied",
                "已复制 \(totalCount) 个文件",
                locale: locale
            )
        case .image:
            return L10n.text("Image copied", "图片已复制", locale: locale)
        case .other:
            return L10n.text("Item copied", "项目已复制", locale: locale)
        }
    }

    var preview: String? {
        preview(in: .english)
    }

    func preview(in locale: InterfaceLocale) -> String? {
        switch self {
        case .text(let text):
            return TextPreview.make(text)
        case .calculation(let expression, let result):
            return "\(TextPreview.make(expression, limit: 64)) = \(result)"
        case .englishWord(let word, let definition):
            return "\(word) · \(TextPreview.make(definition, limit: 180))"
        case .chineseCharacter(let character, _, _):
            return character
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
            let suffix = totalCount > 2
                ? L10n.text(
                    " +\(totalCount - 2) more",
                    "，另有 \(totalCount - 2) 个",
                    locale: locale
                )
                : ""
            return names.joined(separator: ", ") + suffix
        case .image(let thumbnail):
            return thumbnail == nil
                ? L10n.text("Ready to paste", "可以粘贴", locale: locale)
                : nil
        case .other:
            return nil
        }
    }

    var symbolName: String {
        switch self {
        case .calculation:
            return "function"
        case .englishWord:
            return "character.book.closed.fill"
        case .chineseCharacter:
            return "character.textbox"
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
        using searchProvider: WebSearchProvider? = .duckDuckGo,
        locale: InterfaceLocale = .english,
        declarativePlugins: [DeclarativePluginManifest] = [],
        enabledPluginIDs: Set<ClipboardActionPluginID> = Set(
            ClipboardActionPluginID.allCases
        )
    ) -> ClipboardActionDescriptor? {
        for plugin in declarativePlugins {
            if let action = plugin.action(for: self, locale: locale) {
                return action
            }
        }

        return ClipboardActionRegistry.builtIn.primaryAction(
            for: self,
            context: ClipboardPluginContext(
                searchProvider: searchProvider,
                locale: locale
            ),
            enabledPluginIDs: enabledPluginIDs
        )
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
