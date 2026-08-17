import AppKit
import SwiftUI

struct ClipboardFeedbackSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            DetectionSettingsView(settings: settings)
                .tabItem {
                    Label("Plugins", systemImage: "puzzlepiece.extension")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 560, height: 440)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Form {
            Section("CopyThat") {
                Toggle("Enable copy feedback", isOn: $settings.isEnabled)
                Text("Show a floating confirmation whenever the system clipboard changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Search") {
                Picker("Search engine", selection: $settings.searchEngine) {
                    ForEach(SearchEngineOption.allCases) { engine in
                        Text(engine.title).tag(engine)
                    }
                }
                .pickerStyle(.menu)

                if settings.searchEngine == .custom {
                    TextField(
                        "Search engine name",
                        text: $settings.customSearchEngineName
                    )
                    TextField(
                        "URL template",
                        text: $settings.customSearchURLTemplate,
                        prompt: Text("https://example.com/search?q={query}")
                    )

                    Text("Use {query} once in an http:// or https:// query parameter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !settings.customSearchURLTemplate.isEmpty,
                       !settings.isCustomSearchTemplateValid {
                        Text("Enter a valid web URL containing one {query} placeholder.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text("Search runs only after you click the button in the copy popup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )

                if let message = settings.launchAtLoginMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                GlassEffectSettingsCard(settings: settings)

                if #available(macOS 26.0, *) {
                    if reduceTransparency {
                        Label("Liquid Glass is reduced by macOS", systemImage: "accessibility")
                        Text("Turn off Reduce Transparency in System Settings → Accessibility → Display to see the full glass effect.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Interactive Liquid Glass is active", systemImage: "sparkles")
                    }
                } else {
                    Text("System Material is used on this macOS version.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
}

private struct GlassEffectSettingsCard: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            glassPreview

            HStack(alignment: .top, spacing: 12) {
                Label("Glass style", systemImage: "circle.lefthalf.filled")
                    .fixedSize()
                    .frame(width: 96, alignment: .leading)
                    .padding(.top, 2)

                GlassStyleSlider(
                    value: settings.glassEffectStrength,
                    valueLabel: metrics.label,
                    onChange: settings.setGlassEffectStrength
                )
                .frame(maxWidth: .infinity)
            }

            Text(styleDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var metrics: GlassAppearanceMetrics {
        GlassAppearanceMetrics(strength: settings.glassEffectStrength)
    }

    private var styleDescription: String {
        switch metrics.level {
        case .clear:
            return "Clear · Native transparent glass with maximum background visibility."
        case .balanced:
            return "Balanced · Native regular Liquid Glass with system-managed legibility."
        case .strong:
            return "Strong · Native regular Liquid Glass with a subtle semantic tint."
        }
    }

    @ViewBuilder
    private var glassPreview: some View {
        ZStack {
            previewBackdrop

            if #available(macOS 26.0, *), !reduceTransparency {
                let glass: Glass = metrics.usesClearGlass ? .clear : .regular
                previewContent
                    .glassEffect(
                        metrics.usesStrongTint
                            ? glass.tint(
                                Color.blue.opacity(metrics.nativeTintOpacity)
                            ).interactive()
                            : glass.interactive(),
                        in: .rect(cornerRadius: 16)
                    )
                    .padding(10)
            } else {
                previewContent
                    .background(
                        fallbackSurfaceColor,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .background(
                        Color.blue.opacity(metrics.fallbackAccentOpacity),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
                    .padding(10)
            }
        }
        .frame(height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var previewContent: some View {
        HStack(spacing: 10) {
            Image("ThemeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Liquid Glass · \(metrics.label)")
                    .font(.subheadline.weight(.semibold))
                Text(colorScheme == .dark ? "Dark appearance" : "Light appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private var previewBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .blue.opacity(0.62),
                    .purple.opacity(0.5),
                    .mint.opacity(0.42)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Circle()
                .fill(.white.opacity(0.28))
                .frame(width: 72, height: 72)
                .offset(x: -138, y: 22)

            Circle()
                .fill(.orange.opacity(0.33))
                .frame(width: 58, height: 58)
                .offset(x: 150, y: -24)
        }
    }

    private var fallbackSurfaceColor: Color {
        colorScheme == .dark
            ? .black.opacity(metrics.fallbackSurfaceOpacity)
            : .white.opacity(metrics.fallbackSurfaceOpacity)
    }
}

private struct GlassStyleSlider: View {
    let value: Double
    let valueLabel: String
    let onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let startX = GlassStyleSliderGeometry.position(for: 0, width: width)
                let endX = GlassStyleSliderGeometry.position(for: 1, width: width)
                let thumbX = GlassStyleSliderGeometry.position(for: value, width: width)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: max(endX - startX, 1), height: 5)
                        .position(x: (startX + endX) / 2, y: 11)

                    ForEach([0.0, 0.5, 1.0], id: \.self) { level in
                        Circle()
                            .fill(.secondary.opacity(0.38))
                            .frame(width: 4, height: 4)
                            .position(
                                x: GlassStyleSliderGeometry.position(
                                    for: level,
                                    width: width
                                ),
                                y: 11
                            )
                    }

                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.75), lineWidth: 0.75)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                        .position(x: thumbX, y: 11)
                        .animation(.easeOut(duration: 0.12), value: value)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            onChange(
                                GlassStyleSliderGeometry.value(
                                    at: gesture.location.x,
                                    width: width
                                )
                            )
                        }
                )
            }
            .frame(height: 22)

            GeometryReader { geometry in
                let width = geometry.size.width

                Text("Clear")
                    .position(
                        x: GlassStyleSliderGeometry.position(for: 0, width: width),
                        y: 8
                    )
                Text("Balanced")
                    .position(
                        x: GlassStyleSliderGeometry.position(for: 0.5, width: width),
                        y: 8
                    )
                Text("Strong")
                    .position(
                        x: GlassStyleSliderGeometry.position(for: 1, width: width),
                        y: 8
                    )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 17)
        }
        .accessibilityElement()
        .accessibilityLabel("Glass style")
        .accessibilityValue(valueLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(min(value + 0.5, 1))
            case .decrement:
                onChange(max(value - 0.5, 0))
            @unknown default:
                break
            }
        }
    }

}

struct GlassStyleSliderGeometry {
    static let endpointInset: CGFloat = 28

    static func position(for value: Double, width: CGFloat) -> CGFloat {
        let usableWidth = max(width - endpointInset * 2, 0)
        let clampedValue = CGFloat(min(max(value, 0), 1))
        return endpointInset + usableWidth * clampedValue
    }

    static func value(at x: CGFloat, width: CGFloat) -> Double {
        let usableWidth = max(width - endpointInset * 2, 1)
        let rawValue = Double((x - endpointInset) / usableWidth)
        return GlassAppearanceMetrics(strength: rawValue).strength
    }
}

private struct DetectionSettingsView: View {
    @ObservedObject var settings: SettingsManager

    private var standardKinds: [ClipboardContentKind] {
        ClipboardContentKind.allCases.filter { $0 != .code }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Content Plugins")
                    .font(.title3.weight(.semibold))

                VStack(spacing: 0) {
                    ForEach(standardKinds) { kind in
                        DetectionToggleRow(
                            kind: kind,
                            isEnabled: Binding(
                                get: { settings.isDetectionEnabled(kind) },
                                set: { settings.setDetection(kind, enabled: $0) }
                            )
                        )

                        if kind != standardKinds.last {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                Text("Developer Mode")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                DetectionToggleRow(
                    kind: .code,
                    isEnabled: Binding(
                        get: { settings.isDetectionEnabled(.code) },
                        set: { settings.setDetection(.code, enabled: $0) }
                    )
                )
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                Text("Code recognition uses bounded local rules. JSON and Python can be formatted only after you click Format.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Action Plugins")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(ClipboardActionPluginID.allCases) { plugin in
                        ActionPluginToggleRow(
                            plugin: plugin,
                            isEnabled: Binding(
                                get: { settings.isActionPluginEnabled(plugin) },
                                set: { settings.setActionPlugin(plugin, enabled: $0) }
                            )
                        )

                        if plugin != ClipboardActionPluginID.allCases.last {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                Text("Plugins run only after the clipboard changes. Everything stays local, and disabled content falls back to ordinary copy feedback.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

private struct ActionPluginToggleRow: View {
    let plugin: ClipboardActionPluginID
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: plugin.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(plugin.title)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

private struct DetectionToggleRow: View {
    let kind: ClipboardContentKind
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.system(size: 14, weight: .medium))
                Text(kind.subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text(Bundle.main.copyThatDisplayName)
                .font(.title2.weight(.semibold))

            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)

            Text("Private, local copy confirmation with useful next actions.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.0.0"
    }
}
