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

    var title: String {
        switch self {
        case .search: return "Search"
        case .openSafari: return "Open in Safari"
        case .call: return "Call"
        case .composeEmail: return "Compose Email"
        case .revealInFinder: return "Show in Finder"
        case .formatCode: return "Format Code"
        case .copyCalculation: return "Copy Result"
        case .characterDetails: return "Character Details"
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

    var subtitle: String {
        switch self {
        case .search:
            return "Show Search for ordinary copied text."
        case .openSafari:
            return "Show Open Safari when a link is recognized."
        case .call:
            return "Show Call when a phone number is recognized."
        case .composeEmail:
            return "Show Compose when an email address is recognized."
        case .revealInFinder:
            return "Show copied files in Finder."
        case .formatCode:
            return "Show Format for supported JSON and Python code."
        case .copyCalculation:
            return "Show Copy Result. Calculations still display when this is off."
        case .characterDetails:
            return "Show a separate full definition window. Pinyin still displays when off."
        }
    }
}

struct ClipboardPluginContext {
    let searchProvider: WebSearchProvider?
}

/// Action plugins convert analyzed content into a single user-invoked action.
/// They do no work while the clipboard is idle and never mutate content during
/// recognition. Add future actions by implementing this protocol and registering
/// one value in ClipboardActionRegistry.builtIn.
protocol ClipboardActionPlugin {
    var id: ClipboardActionPluginID { get }
    func action(
        for content: ClipboardContent,
        context: ClipboardPluginContext
    ) -> ClipboardActionDescriptor?
}

struct ClipboardActionRegistry {
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
        for plugin in plugins where enabledPluginIDs.contains(plugin.id) {
            if let action = plugin.action(for: content, context: context) {
                return action
            }
        }
        return nil
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
            title: "Search",
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
            title: "Open Safari",
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
            title: "Call",
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
            title: "Compose",
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
            title: "Show in Finder",
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
            title: "Format",
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
            title: "Copy Result",
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
            title: "Details",
            systemImage: id.symbolName,
            target: .showReference(
                ClipboardReference(
                    title: character,
                    subtitle: pinyin,
                    body: definition ?? "No local dictionary definition was found."
                )
            )
        )
    }
}
