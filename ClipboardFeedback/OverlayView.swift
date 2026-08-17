import SwiftUI

struct OverlayView: View {
    let content: ClipboardContent
    let glassEffectStrength: Double
    let usesNativeGlassBackground: Bool
    let primaryAction: ClipboardActionDescriptor?
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
                    Text(content.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if let action = primaryAction {
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

                if let preview = content.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textSelection(.disabled)
                }

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
                        .accessibilityLabel("Copied image preview")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 392, alignment: .leading)
        .contentShape(.rect)
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
