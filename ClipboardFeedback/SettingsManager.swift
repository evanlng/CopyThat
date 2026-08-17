import Foundation
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private enum Key {
        static let feedbackEnabled = "feedbackEnabled"
        static let disabledDetectionKinds = "disabledDetectionKinds"
        static let disabledActionPlugins = "disabledActionPlugins"
        static let uninstalledDetectionKinds = "uninstalledDetectionKinds"
        static let uninstalledActionPlugins = "uninstalledActionPlugins"
        static let disabledDeclarativePlugins = "disabledDeclarativePlugins"
        static let declarativePluginOrder = "declarativePluginOrder"
        static let appLanguage = "appLanguage"
        static let searchEngine = "searchEngine"
        static let customSearchEngineName = "customSearchEngineName"
        static let customSearchURLTemplate = "customSearchURLTemplate"
        static let glassEffectStrength = "glassEffectStrengthV2"
    }

    private let defaults: UserDefaults
    private let declarativePluginDirectory: URL

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Key.feedbackEnabled)
        }
    }

    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginMessage: String?
    @Published private(set) var disabledDetectionKindIDs: Set<String>
    @Published private(set) var disabledActionPluginIDs: Set<String>
    @Published private(set) var uninstalledDetectionKindIDs: Set<String>
    @Published private(set) var uninstalledActionPluginIDs: Set<String>
    @Published private(set) var disabledDeclarativePluginIDs: Set<String>
    @Published private(set) var installedDeclarativePlugins: [DeclarativePluginManifest]

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Key.appLanguage)
        }
    }

    @Published var searchEngine: SearchEngineOption {
        didSet {
            defaults.set(searchEngine.rawValue, forKey: Key.searchEngine)
        }
    }

    @Published var customSearchEngineName: String {
        didSet {
            defaults.set(customSearchEngineName, forKey: Key.customSearchEngineName)
        }
    }

    @Published var customSearchURLTemplate: String {
        didSet {
            defaults.set(customSearchURLTemplate, forKey: Key.customSearchURLTemplate)
        }
    }

    @Published private(set) var glassEffectStrength: Double

    init(
        defaults: UserDefaults = .standard,
        declarativePluginDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.declarativePluginDirectory = declarativePluginDirectory
            ?? Self.defaultDeclarativePluginDirectory
        if defaults.object(forKey: Key.feedbackEnabled) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: Key.feedbackEnabled)
        }
        self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.disabledDetectionKindIDs = Set(
            defaults.stringArray(forKey: Key.disabledDetectionKinds) ?? []
        )
        self.disabledActionPluginIDs = Set(
            defaults.stringArray(forKey: Key.disabledActionPlugins) ?? []
        )
        self.uninstalledDetectionKindIDs = Set(
            defaults.stringArray(forKey: Key.uninstalledDetectionKinds) ?? []
        )
        self.uninstalledActionPluginIDs = Set(
            defaults.stringArray(forKey: Key.uninstalledActionPlugins) ?? []
        )
        self.disabledDeclarativePluginIDs = Set(
            defaults.stringArray(forKey: Key.disabledDeclarativePlugins) ?? []
        )
        self.installedDeclarativePlugins = []
        self.appLanguage = AppLanguage(
            rawValue: defaults.string(forKey: Key.appLanguage) ?? ""
        ) ?? .system
        self.searchEngine = SearchEngineOption(
            rawValue: defaults.string(forKey: Key.searchEngine) ?? ""
        ) ?? .duckDuckGo
        self.customSearchEngineName = defaults.string(
            forKey: Key.customSearchEngineName
        ) ?? "Custom"
        self.customSearchURLTemplate = defaults.string(
            forKey: Key.customSearchURLTemplate
        ) ?? ""
        if defaults.object(forKey: Key.glassEffectStrength) == nil {
            self.glassEffectStrength = GlassAppearanceLevel.balanced.rawValue
        } else {
            self.glassEffectStrength = GlassAppearanceMetrics(
                strength: defaults.double(forKey: Key.glassEffectStrength)
            ).strength
        }
        self.installedDeclarativePlugins = Self.loadDeclarativePlugins(
            from: self.declarativePluginDirectory,
            preferredOrder: defaults.stringArray(forKey: Key.declarativePluginOrder) ?? []
        )
    }

    func setGlassEffectStrength(_ value: Double) {
        let snapped = GlassAppearanceMetrics(strength: value).strength
        guard glassEffectStrength != snapped else { return }
        glassEffectStrength = snapped
        defaults.set(snapped, forKey: Key.glassEffectStrength)
    }

    var activeSearchProvider: WebSearchProvider? {
        if let builtInProvider = searchEngine.builtInProvider {
            return builtInProvider
        }

        let trimmedName = customSearchEngineName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let provider = WebSearchProvider(
            name: trimmedName.isEmpty ? "Custom" : trimmedName,
            urlTemplate: customSearchURLTemplate.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
        return provider.isValid ? provider : nil
    }

    var isCustomSearchTemplateValid: Bool {
        let provider = WebSearchProvider(
            name: customSearchEngineName,
            urlTemplate: customSearchURLTemplate.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
        return provider.isValid
    }

    var enabledDetectionKinds: Set<ClipboardContentKind> {
        Set(ClipboardContentKind.allCases.filter {
            isDetectionInstalled($0) && !disabledDetectionKindIDs.contains($0.rawValue)
        })
    }

    var enabledActionPluginIDs: Set<ClipboardActionPluginID> {
        Set(ClipboardActionPluginID.allCases.filter {
            isActionPluginInstalled($0) && !disabledActionPluginIDs.contains($0.rawValue)
        })
    }

    var enabledDeclarativePlugins: [DeclarativePluginManifest] {
        installedDeclarativePlugins.filter {
            !disabledDeclarativePluginIDs.contains($0.identifier)
        }
    }

    var resolvedLocale: InterfaceLocale {
        appLanguage.resolvedLocale
    }

    func isDetectionInstalled(_ kind: ClipboardContentKind) -> Bool {
        !uninstalledDetectionKindIDs.contains(kind.rawValue)
    }

    func isActionPluginInstalled(_ plugin: ClipboardActionPluginID) -> Bool {
        !uninstalledActionPluginIDs.contains(plugin.rawValue)
    }

    func isDetectionEnabled(_ kind: ClipboardContentKind) -> Bool {
        isDetectionInstalled(kind) && !disabledDetectionKindIDs.contains(kind.rawValue)
    }

    func setDetection(_ kind: ClipboardContentKind, enabled: Bool) {
        guard isDetectionInstalled(kind) else { return }
        if enabled {
            disabledDetectionKindIDs.remove(kind.rawValue)
        } else {
            disabledDetectionKindIDs.insert(kind.rawValue)
        }
        defaults.set(
            Array(disabledDetectionKindIDs).sorted(),
            forKey: Key.disabledDetectionKinds
        )
    }

    func isActionPluginEnabled(_ plugin: ClipboardActionPluginID) -> Bool {
        isActionPluginInstalled(plugin) && !disabledActionPluginIDs.contains(plugin.rawValue)
    }

    func setActionPlugin(_ plugin: ClipboardActionPluginID, enabled: Bool) {
        guard isActionPluginInstalled(plugin) else { return }
        if enabled {
            disabledActionPluginIDs.remove(plugin.rawValue)
        } else {
            disabledActionPluginIDs.insert(plugin.rawValue)
        }
        defaults.set(
            Array(disabledActionPluginIDs).sorted(),
            forKey: Key.disabledActionPlugins
        )
    }

    func installDetectionPlugin(_ kind: ClipboardContentKind) {
        uninstalledDetectionKindIDs.remove(kind.rawValue)
        disabledDetectionKindIDs.remove(kind.rawValue)
        persistPluginState()
    }

    func uninstallDetectionPlugin(_ kind: ClipboardContentKind) {
        uninstalledDetectionKindIDs.insert(kind.rawValue)
        disabledDetectionKindIDs.remove(kind.rawValue)
        persistPluginState()
    }

    func installActionPlugin(_ plugin: ClipboardActionPluginID) {
        uninstalledActionPluginIDs.remove(plugin.rawValue)
        disabledActionPluginIDs.remove(plugin.rawValue)
        persistPluginState()
    }

    func uninstallActionPlugin(_ plugin: ClipboardActionPluginID) {
        uninstalledActionPluginIDs.insert(plugin.rawValue)
        disabledActionPluginIDs.remove(plugin.rawValue)
        persistPluginState()
    }

    func isDeclarativePluginEnabled(_ plugin: DeclarativePluginManifest) -> Bool {
        !disabledDeclarativePluginIDs.contains(plugin.identifier)
    }

    func setDeclarativePlugin(
        _ plugin: DeclarativePluginManifest,
        enabled: Bool
    ) {
        guard installedDeclarativePlugins.contains(where: {
            $0.identifier == plugin.identifier
        }) else { return }

        if enabled {
            disabledDeclarativePluginIDs.remove(plugin.identifier)
        } else {
            disabledDeclarativePluginIDs.insert(plugin.identifier)
        }
        persistDeclarativePluginState()
    }

    @discardableResult
    func installDeclarativePlugin(from sourceURL: URL) throws -> DeclarativePluginManifest {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize,
           fileSize > DeclarativePluginManifest.maximumFileSize {
            throw DeclarativePluginValidationError.fileTooLarge
        }

        let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        let manifest = try DeclarativePluginCodec.decodeAndValidate(data)
        let canonicalData = try DeclarativePluginCodec.encoded(manifest)

        try FileManager.default.createDirectory(
            at: declarativePluginDirectory,
            withIntermediateDirectories: true
        )
        try canonicalData.write(
            to: declarativePluginURL(for: manifest.identifier),
            options: .atomic
        )

        installedDeclarativePlugins.removeAll {
            $0.identifier == manifest.identifier
        }
        installedDeclarativePlugins.insert(manifest, at: 0)
        disabledDeclarativePluginIDs.remove(manifest.identifier)
        persistDeclarativePluginState()
        return manifest
    }

    func uninstallDeclarativePlugin(_ plugin: DeclarativePluginManifest) throws {
        guard installedDeclarativePlugins.contains(where: {
            $0.identifier == plugin.identifier
        }) else { return }

        let destination = declarativePluginURL(for: plugin.identifier)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        installedDeclarativePlugins.removeAll {
            $0.identifier == plugin.identifier
        }
        disabledDeclarativePluginIDs.remove(plugin.identifier)
        persistDeclarativePluginState()
    }

    private func persistPluginState() {
        defaults.set(
            Array(disabledDetectionKindIDs).sorted(),
            forKey: Key.disabledDetectionKinds
        )
        defaults.set(
            Array(disabledActionPluginIDs).sorted(),
            forKey: Key.disabledActionPlugins
        )
        defaults.set(
            Array(uninstalledDetectionKindIDs).sorted(),
            forKey: Key.uninstalledDetectionKinds
        )
        defaults.set(
            Array(uninstalledActionPluginIDs).sorted(),
            forKey: Key.uninstalledActionPlugins
        )
    }

    private func persistDeclarativePluginState() {
        defaults.set(
            Array(disabledDeclarativePluginIDs).sorted(),
            forKey: Key.disabledDeclarativePlugins
        )
        defaults.set(
            installedDeclarativePlugins.map(\.identifier),
            forKey: Key.declarativePluginOrder
        )
    }

    private func declarativePluginURL(for identifier: String) -> URL {
        declarativePluginDirectory
            .appendingPathComponent(identifier)
            .appendingPathExtension("copythatplugin")
    }

    private static var defaultDeclarativePluginDirectory: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("CopyThat", isDirectory: true)
            .appendingPathComponent("Plugins", isDirectory: true)
    }

    private static func loadDeclarativePlugins(
        from directory: URL,
        preferredOrder: [String]
    ) -> [DeclarativePluginManifest] {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var pluginsByID: [String: DeclarativePluginManifest] = [:]
        for fileURL in fileURLs where fileURL.pathExtension == "copythatplugin" {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  (values.fileSize ?? 0) <= DeclarativePluginManifest.maximumFileSize,
                  let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
                  let manifest = try? DeclarativePluginCodec.decodeAndValidate(data),
                  fileURL.deletingPathExtension().lastPathComponent == manifest.identifier else {
                continue
            }
            pluginsByID[manifest.identifier] = manifest
        }

        var ordered: [DeclarativePluginManifest] = []
        for identifier in preferredOrder {
            if let plugin = pluginsByID.removeValue(forKey: identifier) {
                ordered.append(plugin)
            }
        }
        ordered.append(contentsOf: pluginsByID.values.sorted {
            $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
        })
        return ordered
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = enabled
                ? L10n.text(
                    "Move the app to Applications, then try again.",
                    "请先将 App 移到“应用程序”文件夹，然后重试。",
                    locale: resolvedLocale
                )
                : L10n.text(
                    "Could not update the login item.",
                    "无法更新登录项。",
                    locale: resolvedLocale
                )
        }

        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
