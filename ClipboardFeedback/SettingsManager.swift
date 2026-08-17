import Foundation
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private enum Key {
        static let feedbackEnabled = "feedbackEnabled"
        static let disabledDetectionKinds = "disabledDetectionKinds"
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

    private init(defaults: UserDefaults = .standard) {
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
            !disabledDetectionKindIDs.contains($0.rawValue)
        })
    }

    func isDetectionEnabled(_ kind: ClipboardContentKind) -> Bool {
        !disabledDetectionKindIDs.contains(kind.rawValue)
    }

    func setDetection(_ kind: ClipboardContentKind, enabled: Bool) {
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
                ? "Move the app to Applications, then try again."
                : "Could not update the login item."
        }

        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
