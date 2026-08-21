import Foundation

/// Stable identifiers are persisted in UserDefaults, so plugin preferences
/// survive implementation changes without coupling Settings to concrete types.
enum ClipboardActionPluginID: String, CaseIterable, Identifiable {
    case search
    case openSafari
    case call
    case composeEmail
    case revealInFinder
    case formatCode
    case copyCalculation
    case characterDetails

    var id: String { rawValue }

    func title(in locale: InterfaceLocale) -> String {
        switch self {
        case .search: return L10n.text("Search", "搜索", locale: locale)
        case .openSafari: return L10n.text("Open in Safari", "在 Safari 中打开", locale: locale)
        case .call: return L10n.text("Call", "拨打电话", locale: locale)
        case .composeEmail: return L10n.text("Compose Email", "撰写邮件", locale: locale)
        case .revealInFinder: return L10n.text("Show in Finder", "在访达中显示", locale: locale)
        case .formatCode: return L10n.text("Format Code", "格式化代码", locale: locale)
        case .copyCalculation: return L10n.text("Copy Result", "复制结果", locale: locale)
        case .characterDetails: return L10n.text("Character Details", "汉字详情", locale: locale)
        }
    }

    var symbolName: String {
        switch self {
        case .search: return "magnifyingglass"
        case .openSafari: return "safari"
        case .call: return "phone.fill"
        case .composeEmail: return "envelope.fill"
        case .revealInFinder: return "folder"
        case .formatCode: return "text.alignleft"
        case .copyCalculation: return "document.on.document"
        case .characterDetails: return "character.textbox"
        }
    }

    func subtitle(in locale: InterfaceLocale) -> String {
        switch self {
        case .search:
            return L10n.text("Show Search for ordinary copied text.", "为普通文字显示搜索按钮。", locale: locale)
        case .openSafari:
            return L10n.text("Show Open Safari when a link is recognized.", "识别链接后显示 Safari 打开按钮。", locale: locale)
        case .call:
            return L10n.text("Show Call when a phone number is recognized.", "识别电话号码后显示拨打按钮。", locale: locale)
        case .composeEmail:
            return L10n.text("Show Compose when an email address is recognized.", "识别邮箱后显示撰写邮件按钮。", locale: locale)
        case .revealInFinder:
            return L10n.text("Show copied files in Finder.", "在访达中定位复制的文件。", locale: locale)
        case .formatCode:
            return L10n.text("Show Format for supported JSON and Python code.", "为支持的 JSON 和 Python 代码显示格式化按钮。", locale: locale)
        case .copyCalculation:
            return L10n.text("Show Copy Result. Calculations still display when this is off.", "显示复制结果按钮；关闭后仍会显示计算结果。", locale: locale)
        case .characterDetails:
            return L10n.text("Show a separate full definition window. Pinyin still displays when off.", "显示完整释义窗口；关闭后拼音仍会自动显示。", locale: locale)
        }
    }
}

struct ClipboardPluginContext {
    let searchProvider: WebSearchProvider?
    let locale: InterfaceLocale
}

/// Action plugins convert analyzed content into a single user-invoked action.
/// They do no work while the clipboard is idle and never mutate content during
/// recognition. Add future actions by implementing this protocol and registering
/// one value in ClipboardActionRegistry.builtIn.
protocol ClipboardActionPlugin: Sendable {
    var id: ClipboardActionPluginID { get }
    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor?
}

struct ClipboardActionRegistry: Sendable {
    static let builtIn = ClipboardActionRegistry(plugins: [
        SearchActionPlugin(),
        OpenSafariActionPlugin(),
        CallActionPlugin(),
        ComposeEmailActionPlugin(),
        RevealInFinderActionPlugin(),
        FormatCodeActionPlugin(),
        CopyCalculationActionPlugin(),
        CharacterDetailsActionPlugin()
    ])

    private let plugins: [any ClipboardActionPlugin]

    init(plugins: [any ClipboardActionPlugin]) {
        self.plugins = plugins
    }

    func primaryAction(
        for content: ClipboardContent,
        context: ClipboardPluginContext,
        enabledPluginIDs: Set<ClipboardActionPluginID>
    ) -> ClipboardActionDescriptor? {
        actions(
            for: content,
            context: context,
            enabledPluginIDs: enabledPluginIDs
        ).first
    }

    func actions(
        for content: ClipboardContent,
        context: ClipboardPluginContext,
        enabledPluginIDs: Set<ClipboardActionPluginID>
    ) -> [ClipboardActionDescriptor] {
        for plugin in plugins where enabledPluginIDs.contains(plugin.id) {
            if let action = plugin.action(for: content, context: context) {
                return [action]
            }
        }
        return []
    }
}

private struct SearchActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.search

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .text(let text) = content,
              let searchURL = context.searchProvider?.searchURL(for: text) else {
            return nil
        }
        return ClipboardActionDescriptor(
            title: id.title(in: context.locale),
            systemImage: id.symbolName,
            target: .external(
                .openInApplication(
                    urls: [searchURL],
                    bundleIdentifier: "com.apple.Safari"
                )
            )
        )
    }
}

private struct OpenSafariActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.openSafari

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .link(let url) = content else { return nil }
        return ClipboardActionDescriptor(
            title: L10n.text("Open Safari", "打开 Safari", locale: context.locale),
            systemImage: id.symbolName,
            target: .external(
                .openInApplication(
                    urls: [url],
                    bundleIdentifier: "com.apple.Safari"
                )
            )
        )
    }
}

private struct CallActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.call

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .phoneNumber(_, let normalized) = content,
              let url = URL(string: "tel:\(normalized)") else { return nil }
        return ClipboardActionDescriptor(
            title: id.title(in: context.locale),
            systemImage: id.symbolName,
            target: .external(.openDefault(url))
        )
    }
}

private struct ComposeEmailActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.composeEmail

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .emailAddress(let email) = content,
              let encoded = email.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
              ),
              let url = URL(string: "mailto:\(encoded)") else { return nil }
        return ClipboardActionDescriptor(
            title: L10n.text("Compose", "写邮件", locale: context.locale),
            systemImage: id.symbolName,
            target: .external(.openDefault(url))
        )
    }
}

private struct RevealInFinderActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.revealInFinder

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .files(let urls, _) = content, !urls.isEmpty else { return nil }
        return ClipboardActionDescriptor(
            title: id.title(in: context.locale),
            systemImage: id.symbolName,
            target: .external(.revealInFinder(urls))
        )
    }
}

private struct FormatCodeActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.formatCode

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .code(let language, _, .some(let source)) = content,
              language.supportsBasicFormatting else { return nil }
        return ClipboardActionDescriptor(
            title: L10n.text("Format", "格式化", locale: context.locale),
            systemImage: id.symbolName,
            target: .formatCode(language: language, source: source)
        )
    }
}

private struct CopyCalculationActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.copyCalculation

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .calculation(_, let result) = content else { return nil }
        return ClipboardActionDescriptor(
            title: id.title(in: context.locale),
            systemImage: id.symbolName,
            target: .copyText(result)
        )
    }
}

private struct CharacterDetailsActionPlugin: ClipboardActionPlugin {
    let id = ClipboardActionPluginID.characterDetails

    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor? {
        guard case .chineseCharacter(
            let character,
            let pinyin,
            let definition
        ) = content else { return nil }
        return ClipboardActionDescriptor(
            title: L10n.text("Details", "详情", locale: context.locale),
            systemImage: id.symbolName,
            target: .showReference(
                ClipboardReference(
                    title: character,
                    subtitle: pinyin,
                    body: definition ?? L10n.text(
                        "No local dictionary definition was found.",
                        "未找到本地词典释义。",
                        locale: context.locale
                    )
                )
            )
        )
    }
}
