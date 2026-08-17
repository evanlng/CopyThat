import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardFeedbackSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label(t("General", "通用"), systemImage: "gearshape")
                }

            DetectionSettingsView(settings: settings)
                .tabItem {
                    Label(t("Plugins", "插件"), systemImage: "puzzlepiece.extension")
                }

            AboutSettingsView(settings: settings)
                .tabItem {
                    Label(t("About", "关于"), systemImage: "info.circle")
                }
        }
        .environment(\.locale, settings.resolvedLocale.locale)
        .frame(width: 560, height: 440)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Form {
            Section(Bundle.main.copyThatDisplayName(in: settings.resolvedLocale)) {
                Toggle(t("Enable copy feedback", "启用复制反馈"), isOn: $settings.isEnabled)
                Text(t(
                    "Show a floating confirmation whenever the system clipboard changes.",
                    "系统剪贴板发生变化时显示确认浮窗。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(t("Language", "语言")) {
                Picker(t("Interface language", "界面语言"), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title(in: settings.resolvedLocale)).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Text(t(
                    "Automatic matches the current macOS language. Changes take effect immediately.",
                    "自动模式会匹配当前 macOS 语言，切换后立即生效。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section(t("Search", "搜索")) {
                Picker(t("Search engine", "搜索引擎"), selection: $settings.searchEngine) {
                    ForEach(SearchEngineOption.allCases) { engine in
                        Text(
                            engine == .custom
                                ? t("Custom", "自定义")
                                : engine.title
                        ).tag(engine)
                    }
                }
                .pickerStyle(.menu)

                if settings.searchEngine == .custom {
                    TextField(
                        t("Search engine name", "搜索引擎名称"),
                        text: $settings.customSearchEngineName
                    )
                    TextField(
                        t("URL template", "URL 模板"),
                        text: $settings.customSearchURLTemplate,
                        prompt: Text("https://example.com/search?q={query}")
                    )

                    Text(t(
                        "Use {query} once in an http:// or https:// query parameter.",
                        "在 http:// 或 https:// 查询参数中使用一次 {query}。"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !settings.customSearchURLTemplate.isEmpty,
                       !settings.isCustomSearchTemplateValid {
                        Text(t(
                            "Enter a valid web URL containing one {query} placeholder.",
                            "请输入包含一个 {query} 占位符的有效网址。"
                        ))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text(t(
                    "Search runs only after you click the button in the copy popup.",
                    "只有点击复制浮窗中的按钮后才会执行搜索。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(t("Startup", "启动")) {
                Toggle(
                    t("Launch at Login", "登录时启动"),
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

            Section(t("Appearance", "外观")) {
                GlassEffectSettingsCard(settings: settings)

                if #available(macOS 26.0, *) {
                    if reduceTransparency {
                        Label(t("Liquid Glass is reduced by macOS", "macOS 已减弱液态玻璃效果"), systemImage: "accessibility")
                        Text(t(
                            "Turn off Reduce Transparency in System Settings → Accessibility → Display to see the full glass effect.",
                            "请在系统设置 → 辅助功能 → 显示中关闭“降低透明度”，以查看完整玻璃效果。"
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(t("Interactive Liquid Glass is active", "交互式液态玻璃已启用"), systemImage: "sparkles")
                    }
                } else {
                    Text(t("System Material is used on this macOS version.", "当前 macOS 版本使用系统材质。"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
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
                Label(t("Glass style", "玻璃样式"), systemImage: "circle.lefthalf.filled")
                    .fixedSize()
                    .frame(width: 96, alignment: .leading)
                    .padding(.top, 2)

                GlassStyleSlider(
                    value: settings.glassEffectStrength,
                    valueLabel: localizedMetricsLabel,
                    locale: settings.resolvedLocale,
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
            return t(
                "Clear · Native transparent glass with maximum background visibility.",
                "清透 · 原生透明玻璃，最大程度显示背景。"
            )
        case .balanced:
            return t(
                "Balanced · Native regular Liquid Glass with system-managed legibility.",
                "均衡 · 原生常规液态玻璃，由系统保证可读性。"
            )
        case .strong:
            return t(
                "Strong · Native regular Liquid Glass with a subtle semantic tint.",
                "强烈 · 原生常规液态玻璃，并加入轻微语义色调。"
            )
        }
    }

    private var localizedMetricsLabel: String {
        switch metrics.level {
        case .clear: return t("Clear", "清透")
        case .balanced: return t("Balanced", "均衡")
        case .strong: return t("Strong", "强烈")
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
                Text("Liquid Glass · \(localizedMetricsLabel)")
                    .font(.subheadline.weight(.semibold))
                Text(
                    colorScheme == .dark
                        ? t("Dark appearance", "深色外观")
                        : t("Light appearance", "浅色外观")
                )
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

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
    }
}

private struct GlassStyleSlider: View {
    let value: Double
    let valueLabel: String
    let locale: InterfaceLocale
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

                Text(L10n.text("Clear", "清透", locale: locale))
                    .position(
                        x: GlassStyleSliderGeometry.position(for: 0, width: width),
                        y: 8
                    )
                Text(L10n.text("Balanced", "均衡", locale: locale))
                    .position(
                        x: GlassStyleSliderGeometry.position(for: 0.5, width: width),
                        y: 8
                    )
                Text(L10n.text("Strong", "强烈", locale: locale))
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
        .accessibilityLabel(L10n.text("Glass style", "玻璃样式", locale: locale))
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
    @State private var pluginMessage: String?

    private var installedDetectionKinds: [ClipboardContentKind] {
        ClipboardContentKind.allCases.filter(settings.isDetectionInstalled)
    }

    private var availableDetectionKinds: [ClipboardContentKind] {
        ClipboardContentKind.allCases.filter { !settings.isDetectionInstalled($0) }
    }

    private var installedActionPlugins: [ClipboardActionPluginID] {
        ClipboardActionPluginID.allCases.filter(settings.isActionPluginInstalled)
    }

    private var availableActionPlugins: [ClipboardActionPluginID] {
        ClipboardActionPluginID.allCases.filter { !settings.isActionPluginInstalled($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Install a Plugin", "安装插件"))
                    .font(.title3.weight(.semibold))

                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Import a CopyThat plugin", "导入 CopyThat 插件"))
                            .font(.system(size: 14, weight: .medium))
                        Text(t(
                            "Choose a .copythatplugin file. Imported plugins are data-only HTTPS actions and never run third-party code.",
                            "选择 .copythatplugin 文件。导入插件只包含 HTTPS 操作数据，不会运行第三方代码。"
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button(action: choosePlugin) {
                        Label(t("Install Plugin…", "安装插件…"), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(16)
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                if !settings.installedDeclarativePlugins.isEmpty {
                    Text(t("Imported Plugins", "已导入插件"))
                        .font(.title3.weight(.semibold))
                        .padding(.top, 8)

                    Text(t(
                        "The first enabled imported plugin that matches copied content supplies the HUD button.",
                        "第一个匹配复制内容的已启用导入插件会提供浮窗按钮。"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(settings.installedDeclarativePlugins) { plugin in
                            InstalledDeclarativePluginRow(
                                plugin: plugin,
                                locale: settings.resolvedLocale,
                                isEnabled: Binding(
                                    get: { settings.isDeclarativePluginEnabled(plugin) },
                                    set: { settings.setDeclarativePlugin(plugin, enabled: $0) }
                                ),
                                uninstall: { uninstall(plugin) }
                            )

                            if plugin != settings.installedDeclarativePlugins.last {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .background(
                        Color(nsColor: .controlBackgroundColor).opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }

                Text(t("Installed Content Plugins", "已安装的内容插件"))
                    .font(.title3.weight(.semibold))

                Text(t(
                    "Switches pause recognition. Remove moves a plugin to Available Plugins and can be reversed at any time.",
                    "开关用于暂停识别；删除会把插件移到“可安装插件”，随时可以重新安装。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(installedDetectionKinds) { kind in
                        InstalledDetectionPluginRow(
                            kind: kind,
                            locale: settings.resolvedLocale,
                            isEnabled: Binding(
                                get: { settings.isDetectionEnabled(kind) },
                                set: { settings.setDetection(kind, enabled: $0) }
                            ),
                            uninstall: { settings.uninstallDetectionPlugin(kind) }
                        )

                        if kind != installedDetectionKinds.last {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }

                    if installedDetectionKinds.isEmpty {
                        EmptyPluginListRow(
                            message: t("No content plugins installed.", "未安装内容插件。")
                        )
                    }
                }
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                Text(t("Installed Action Plugins", "已安装的操作插件"))
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                Text(t(
                    "Action switches control buttons only. Turning one off does not disable content recognition.",
                    "操作插件开关只控制按钮；关闭后不会停止内容识别。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(installedActionPlugins) { plugin in
                        InstalledActionPluginRow(
                            plugin: plugin,
                            locale: settings.resolvedLocale,
                            isEnabled: Binding(
                                get: { settings.isActionPluginEnabled(plugin) },
                                set: { settings.setActionPlugin(plugin, enabled: $0) }
                            ),
                            uninstall: { settings.uninstallActionPlugin(plugin) }
                        )

                        if plugin != installedActionPlugins.last {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }

                    if installedActionPlugins.isEmpty {
                        EmptyPluginListRow(
                            message: t("No action plugins installed.", "未安装操作插件。")
                        )
                    }
                }
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                if !availableDetectionKinds.isEmpty || !availableActionPlugins.isEmpty {
                    Text(t("Available Plugins", "可安装插件"))
                        .font(.title3.weight(.semibold))
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(availableDetectionKinds) { kind in
                            AvailablePluginRow(
                                title: kind.title(in: settings.resolvedLocale),
                                subtitle: kind.detail(in: settings.resolvedLocale),
                                symbolName: kind.symbolName,
                                category: t("Content", "内容"),
                                installTitle: t("Install", "安装"),
                                install: { settings.installDetectionPlugin(kind) }
                            )
                            Divider().padding(.leading, 46)
                        }

                        ForEach(availableActionPlugins) { plugin in
                            AvailablePluginRow(
                                title: plugin.title(in: settings.resolvedLocale),
                                subtitle: plugin.subtitle(in: settings.resolvedLocale),
                                symbolName: plugin.symbolName,
                                category: t("Action", "操作"),
                                installTitle: t("Install", "安装"),
                                install: { settings.installActionPlugin(plugin) }
                            )

                            if plugin != availableActionPlugins.last {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .background(
                        Color(nsColor: .controlBackgroundColor).opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }

                Text(t(
                    "Built-in plugins do no work while the clipboard is idle. Installing or removing one adds no background service.",
                    "内置插件在剪贴板空闲时不会工作；安装或删除插件都不会增加后台服务。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .alert(
            t("Plugin Installation", "插件安装"),
            isPresented: Binding(
                get: { pluginMessage != nil },
                set: { if !$0 { pluginMessage = nil } }
            )
        ) {
            Button(t("OK", "好"), role: .cancel) {}
        } message: {
            Text(pluginMessage ?? "")
        }
    }

    private func choosePlugin() {
        let panel = NSOpenPanel()
        panel.title = t("Install a CopyThat Plugin", "安装 CopyThat 插件")
        panel.prompt = t("Install", "安装")
        panel.message = t(
            "Select a trusted .copythatplugin manifest.",
            "请选择可信的 .copythatplugin 清单文件。"
        )
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "copythatplugin") ?? .json,
            .json
        ]

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        do {
            let plugin = try settings.installDeclarativePlugin(from: sourceURL)
            pluginMessage = t(
                "Installed \(plugin.displayName(in: settings.resolvedLocale)).",
                "已安装 \(plugin.displayName(in: settings.resolvedLocale))。"
            )
        } catch {
            pluginMessage = t(
                "The plugin could not be installed: \(error.localizedDescription)",
                "无法安装插件：\(error.localizedDescription)"
            )
        }
    }

    private func uninstall(_ plugin: DeclarativePluginManifest) {
        do {
            try settings.uninstallDeclarativePlugin(plugin)
        } catch {
            pluginMessage = t(
                "The plugin could not be removed: \(error.localizedDescription)",
                "无法删除插件：\(error.localizedDescription)"
            )
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
    }
}

private struct InstalledDeclarativePluginRow: View {
    let plugin: DeclarativePluginManifest
    let locale: InterfaceLocale
    @Binding var isEnabled: Bool
    let uninstall: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: plugin.resolvedSystemImage)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plugin.displayName(in: locale))
                        .font(.system(size: 14, weight: .medium))
                    Text(L10n.text("Imported", "已导入", locale: locale))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }
                Text(plugin.displayDescription(in: locale))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()

            Button(role: .destructive, action: uninstall) {
                Label(
                    L10n.text("Remove", "删除", locale: locale),
                    systemImage: "trash"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct InstalledActionPluginRow: View {
    let plugin: ClipboardActionPluginID
    let locale: InterfaceLocale
    @Binding var isEnabled: Bool
    let uninstall: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: plugin.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.title(in: locale))
                    .font(.system(size: 14, weight: .medium))
                Text(plugin.subtitle(in: locale))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()

            Button(role: .destructive, action: uninstall) {
                Label(
                    L10n.text("Remove", "删除", locale: locale),
                    systemImage: "trash"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(L10n.text("Remove plugin", "删除插件", locale: locale))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

private struct InstalledDetectionPluginRow: View {
    let kind: ClipboardContentKind
    let locale: InterfaceLocale
    @Binding var isEnabled: Bool
    let uninstall: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title(in: locale))
                    .font(.system(size: 14, weight: .medium))
                Text(kind.detail(in: locale))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()

            Button(role: .destructive, action: uninstall) {
                Label(
                    L10n.text("Remove", "删除", locale: locale),
                    systemImage: "trash"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(L10n.text("Remove plugin", "删除插件", locale: locale))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

private struct AvailablePluginRow: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let category: String
    let installTitle: String
    let install: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    Text(category)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            Button(installTitle, action: install)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct EmptyPluginListRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }
}

private struct AboutSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text(Bundle.main.copyThatDisplayName(in: settings.resolvedLocale))
                .font(.title2.weight(.semibold))

            Text(t("Version \(appVersion)", "版本 \(appVersion)"))
                .foregroundStyle(.secondary)

            Text(t(
                "Private, local copy confirmation with useful next actions.",
                "私密、本地的复制确认与实用后续操作。"
            ))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.2.0"
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: settings.resolvedLocale)
    }
}
