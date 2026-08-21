import SwiftUI
import Translation

struct OverlayView: View {
    let content: ClipboardContent
    let glassEffectStrength: Double
    let usesNativeGlassBackground: Bool
    let actions: [ClipboardActionDescriptor]
    let locale: InterfaceLocale
    let performAction: (ClipboardActionDescriptor) -> Void
    let onHoverChanged: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if #available(macOS 26.0, *), usesNativeGlassBackground {
                let glass: Glass = metrics.usesClearGlass ? .clear : .regular
                card
                    .glassEffect(
                        metrics.usesStrongTint
                            ? glass.tint(
                                statusColor.opacity(metrics.nativeTintOpacity)
                            ).interactive()
                            : glass.interactive(),
                        in: .rect(cornerRadius: OverlayLayout.cornerRadius)
                    )
            } else {
                fallbackCard
            }
        }
        .padding(OverlayLayout.cardInset)
        .onHover(perform: onHoverChanged)
        .accessibilityElement(children: .contain)
    }

    private var metrics: GlassAppearanceMetrics {
        GlassAppearanceMetrics(strength: glassEffectStrength)
    }

    private var fallbackSurfaceColor: Color {
        colorScheme == .dark
            ? .black.opacity(metrics.fallbackSurfaceOpacity)
            : .white.opacity(metrics.fallbackSurfaceOpacity)
    }

    private var fallbackCard: some View {
        card
            .background(
                fallbackSurfaceColor,
                in: RoundedRectangle(
                    cornerRadius: OverlayLayout.cornerRadius,
                    style: .continuous
                )
            )
            .background(
                statusColor.opacity(metrics.fallbackAccentOpacity),
                in: RoundedRectangle(
                    cornerRadius: OverlayLayout.cornerRadius,
                    style: .continuous
                )
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: OverlayLayout.cornerRadius,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(statusColor.gradient))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(content.title(in: locale))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if !actions.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(actions.prefix(2))) { action in
                                Button {
                                    performAction(action)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: action.systemImage)
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(action.title)
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(statusColor.opacity(0.13), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(statusColor)
                                .help(action.title)
                                .accessibilityLabel(action.title)
                            }
                        }
                    }
                }

                contentDetails

                if let language = content.languageLabel {
                    Text(language)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }

                if let thumbnail = content.imagePreview {
                    Image(nsImage: thumbnail.image)
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFit()
                        .frame(maxWidth: 150, maxHeight: 84, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                        }
                        .accessibilityLabel(
                            L10n.text(
                                "Copied image preview",
                                "已复制图片预览",
                                locale: locale
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 392, alignment: .leading)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var contentDetails: some View {
        switch content {
        case .englishWord(let word, let definition):
            if #available(macOS 15.0, *) {
                BilingualDefinitionView(
                    word: word,
                    definition: definition,
                    locale: locale
                )
            } else {
                OverlayDetailRow(
                    label: L10n.text("English", "英文", locale: locale),
                    value: definition,
                    lineLimit: 4
                )
            }

        case .chineseCharacter(_, let pinyin, let definition):
            VStack(alignment: .leading, spacing: 5) {
                OverlayDetailRow(
                    label: L10n.text("Pinyin", "拼音", locale: locale),
                    value: pinyin,
                    lineLimit: 1
                )
                if let definition, !definition.isEmpty {
                    OverlayDetailRow(
                        label: L10n.text("Meaning", "释义", locale: locale),
                        value: definition,
                        lineLimit: 3
                    )
                }
            }

        default:
            if let preview = content.preview(in: locale), !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .textSelection(.disabled)
            }
        }
    }

    private var statusColor: Color {
        switch content {
        case .calculation: return .orange
        case .englishWord: return .teal
        case .chineseCharacter: return .pink
        case .link: return .blue
        case .phoneNumber: return .green
        case .emailAddress: return .orange
        case .code: return .indigo
        case .files: return .blue
        case .image: return .purple
        case .text, .other: return .green
        }
    }
}

private struct OverlayDetailRow: View {
    let label: String
    let value: String
    let lineLimit: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@available(macOS 15.0, *)
private struct BilingualDefinitionView: View {
    let word: String
    let definition: String
    let locale: InterfaceLocale

    @State private var chineseDefinition = ""
    @State private var needsLanguageDownload = false
    @State private var translationConfiguration: TranslationSession.Configuration?

    private let sourceLanguage = Locale.Language(identifier: "en")
    private let targetLanguage = Locale.Language(identifier: "zh-Hans")

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            OverlayDetailRow(
                label: L10n.text("English", "英文", locale: locale),
                value: definition,
                lineLimit: 4
            )
            HStack(alignment: .top, spacing: 8) {
                Text(L10n.text("Chinese", "中文", locale: locale))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 88, alignment: .leading)

                Text(chineseDefinition)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if needsLanguageDownload {
                    Button(L10n.text("Download", "下载", locale: locale)) {
                        needsLanguageDownload = false
                        chineseDefinition = L10n.text(
                            "Preparing the Chinese meaning…",
                            "正在准备系统中文释义…",
                            locale: locale
                        )
                        translationConfiguration = TranslationSession.Configuration(
                            source: sourceLanguage,
                            target: targetLanguage
                        )
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11.5, weight: .semibold))
                    .help(
                        L10n.text(
                            "Install Apple's on-device English–Chinese translation language pack",
                            "安装 Apple 设备端中英翻译语言包",
                            locale: locale
                        )
                    )
                }
            }
        }
        .task(id: word) {
            chineseDefinition = L10n.text(
                "Checking on-device Chinese translation…",
                "正在检查系统中文翻译…",
                locale: locale
            )
            let status = await LanguageAvailability().status(
                from: sourceLanguage,
                to: targetLanguage
            )

            guard !Task.isCancelled else { return }
            switch status {
            case .installed:
                chineseDefinition = L10n.text(
                    "Preparing the Chinese meaning…",
                    "正在准备系统中文释义…",
                    locale: locale
                )
                translationConfiguration = TranslationSession.Configuration(
                    source: sourceLanguage,
                    target: targetLanguage
                )
            case .supported:
                chineseDefinition = L10n.text(
                    "On-device English–Chinese language pack required",
                    "需要安装系统中英翻译语言包",
                    locale: locale
                )
                needsLanguageDownload = true
            case .unsupported:
                chineseDefinition = L10n.text(
                    "English–Chinese translation is unavailable",
                    "当前系统不支持中英翻译",
                    locale: locale
                )
                needsLanguageDownload = false
            @unknown default:
                chineseDefinition = L10n.text(
                    "Chinese translation is temporarily unavailable",
                    "系统中文翻译暂不可用",
                    locale: locale
                )
                needsLanguageDownload = false
            }
        }
        .translationTask(translationConfiguration) { session in
            do {
                let response = try await session.translate(word)
                await MainActor.run {
                    chineseDefinition = response.targetText
                    needsLanguageDownload = false
                }
            } catch {
                await MainActor.run {
                    chineseDefinition = L10n.text(
                        "On-device English–Chinese language pack required",
                        "需要安装系统中英翻译语言包",
                        locale: locale
                    )
                    needsLanguageDownload = true
                    translationConfiguration = nil
                }
            }
        }
    }
}
