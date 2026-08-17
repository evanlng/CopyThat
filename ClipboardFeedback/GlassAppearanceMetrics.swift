import Foundation

enum GlassAppearanceLevel: Double, Equatable {
    case clear = 0
    case balanced = 0.5
    case strong = 1
}

enum NativeGlassMaterial: Equatable {
    case clear
    case regular
}

struct GlassAppearanceMetrics: Equatable {
    let strength: Double
    let level: GlassAppearanceLevel

    init(strength: Double) {
        let clamped = min(max(strength, 0), 1)
        switch clamped {
        case ..<0.25:
            self.level = .clear
        case ..<0.75:
            self.level = .balanced
        default:
            self.level = .strong
        }
        self.strength = level.rawValue
    }

    var usesClearGlass: Bool {
        level == .clear
    }

    var nativeMaterial: NativeGlassMaterial {
        usesClearGlass ? .clear : .regular
    }

    var usesStrongTint: Bool {
        level == .strong
    }

    var nativeTintOpacity: Double {
        usesStrongTint ? 0.2 : 0
    }

    var fallbackSurfaceOpacity: Double {
        switch level {
        case .clear: return 0.05
        case .balanced: return 0.1
        case .strong: return 0.16
        }
    }

    var fallbackAccentOpacity: Double {
        switch level {
        case .clear: return 0
        case .balanced: return 0.05
        case .strong: return 0.1
        }
    }

    var label: String {
        switch level {
        case .clear: return "Clear"
        case .balanced: return "Balanced"
        case .strong: return "Strong"
        }
    }
}
