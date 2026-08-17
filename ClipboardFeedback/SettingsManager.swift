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
        static let appLanguage = "appLanguage"
        static let searchEngine = "searchEngine"
        static let customSearchEngineName = "customSearchEngineName"
        static let customSearchURLTemplate = "customSearchURLTemplate"
        static let glassEffectStrength = "glassEffectStrengthV2"
    }

    private let defaults: UserDefaults

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
