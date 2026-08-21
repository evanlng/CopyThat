import AppKit

struct ClipboardActionDescriptor: Equatable, Identifiable {
    let title: String
    let systemImage: String
    let target: ClipboardActionTarget

    var id: String { title + systemImage }
}

enum ClipboardActionTarget: Equatable {
    case external(ExternalAppTarget)
    case formatCode(language: CodeLanguage, source: String)
    case copyText(String)
    case showReference(ClipboardReference)
    case runPlugin(PluginScriptInvocation)
}

struct ClipboardReference: Equatable {
    let title: String
    let subtitle: String
    let body: String
}

/// A single audited interface for handing copied content to another app.
enum ExternalAppTarget: Equatable {
    case openInApplication(urls: [URL], bundleIdentifier: String)
    case openDefault(URL)
    case revealInFinder([URL])
}

@MainActor
enum ClipboardActionExecutor {
    @discardableResult
    static func perform(_ action: ClipboardActionDescriptor) -> Bool {
        guard case .external(let target) = action.target else { return false }
        let workspace = NSWorkspace.shared

        switch target {
        case .openInApplication(let urls, let bundleIdentifier):
            guard !urls.isEmpty,
                  let applicationURL = workspace.urlForApplication(
                    withBundleIdentifier: bundleIdentifier
                  ) else {
                return false
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            workspace.open(
                urls,
                withApplicationAt: applicationURL,
                configuration: configuration,
                completionHandler: nil
            )
            return true

        case .openDefault(let url):
            return workspace.open(url)

        case .revealInFinder(let urls):
            guard !urls.isEmpty else { return false }
            workspace.activateFileViewerSelecting(urls)
            return true
        }
    }
}

enum SearchEngineOption: String, CaseIterable, Identifiable {
    case duckDuckGo
    case bing
    case baidu
    case google
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duckDuckGo: return "DuckDuckGo"
        case .bing: return "Bing"
        case .baidu: return "Baidu"
        case .google: return "Google"
        case .custom: return "Custom"
        }
    }

    var builtInProvider: WebSearchProvider? {
        switch self {
        case .duckDuckGo: return .duckDuckGo
        case .bing: return .bing
        case .baidu: return .baidu
        case .google: return .google
        case .custom: return nil
        }
    }
}

struct WebSearchProvider: Equatable {
    let name: String
    let urlTemplate: String

    static let duckDuckGo = WebSearchProvider(
        name: "DuckDuckGo",
        urlTemplate: "https://duckduckgo.com/?q={query}"
    )
    static let bing = WebSearchProvider(
        name: "Bing",
        urlTemplate: "https://www.bing.com/search?q={query}"
    )
    static let baidu = WebSearchProvider(
        name: "Baidu",
        urlTemplate: "https://www.baidu.com/s?wd={query}"
    )
    static let google = WebSearchProvider(
        name: "Google",
        urlTemplate: "https://www.google.com/search?q={query}"
    )

    var isValid: Bool {
        searchURL(for: "validation") != nil
    }

    func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 1_000 else { return nil }

        guard urlTemplate.components(separatedBy: "{query}").count == 2,
              var components = URLComponents(string: urlTemplate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false,
              let queryItems = components.queryItems else {
            return nil
        }

        let placeholderItems = queryItems.filter {
            $0.value?.contains("{query}") == true
        }
        guard placeholderItems.count == 1 else { return nil }

        components.scheme = scheme
        components.queryItems = queryItems.map { item in
            URLQueryItem(
                name: item.name,
                value: item.value?.replacingOccurrences(
                    of: "{query}",
                    with: trimmed
                )
            )
        }
        return components.url
    }
}
