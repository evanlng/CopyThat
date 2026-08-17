import AppKit
import SwiftUI

enum OverlayLayout {
    static let cardInset: CGFloat = 18
    static let cornerRadius: CGFloat = 26
}

enum HUDPositioning {
    static func origin(
        in visibleFrame: NSRect,
        panelSize: NSSize,
        margin: CGFloat
    ) -> NSPoint {
        let centeredX = visibleFrame.midX - panelSize.width / 2
        let minimumX = visibleFrame.minX + margin
        let maximumX = visibleFrame.maxX - panelSize.width - margin
        let x = maximumX >= minimumX
            ? min(max(centeredX, minimumX), maximumX)
            : visibleFrame.minX
        return NSPoint(
            x: x,
            y: visibleFrame.maxY - panelSize.height - margin
        )
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override var needsPanelToBecomeKey: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class OverlayManager {
    private let defaultDisplayDuration: TimeInterval = 1.8
    private let screenMargin: CGFloat = 16
    private let formatterWindowManager = CodeFormatterWindowManager()
    private let referenceWindowManager = PluginReferenceWindowManager()

    private var panel: OverlayPanel?
    private var hostingView: FirstMouseHostingView<OverlayView>?
    private var dismissalWorkItem: DispatchWorkItem?
    private var displayGeneration = 0
    private var currentDisplayDuration: TimeInterval = 1.8

    func show(_ content: ClipboardContent) {
        displayGeneration += 1
        let generation = displayGeneration
        currentDisplayDuration = displayDuration(for: content)
        dismissalWorkItem?.cancel()

        let panel = panel ?? makePanel()
        let wasVisible = panel.isVisible
        let settings = SettingsManager.shared
        let metrics = GlassAppearanceMetrics(strength: settings.glassEffectStrength)
        let usesNativeGlass = shouldUseNativeGlass
        let rootView = OverlayView(
            content: content,
            glassEffectStrength: metrics.strength,
            usesNativeGlassBackground: usesNativeGlass,
            primaryAction: content.primaryAction(
                using: settings.activeSearchProvider,
                locale: settings.resolvedLocale,
                declarativePlugins: settings.enabledDeclarativePlugins,
                enabledPluginIDs: settings.enabledActionPluginIDs
            ),
            locale: settings.resolvedLocale
        ) { action in
            self.perform(action)
        } onHoverChanged: { [weak self] hovering in
            self?.handleHoverChanged(hovering)
        }

        let hostingView: FirstMouseHostingView<OverlayView>
        if let existingHostingView = self.hostingView {
            existingHostingView.rootView = rootView
            hostingView = existingHostingView
        } else {
            let newHostingView = FirstMouseHostingView(rootView: rootView)
            self.hostingView = newHostingView
            hostingView = newHostingView
        }
        hostingView.frame = NSRect(x: 0, y: 0, width: 376, height: 160)
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        let panelSize = NSSize(
            width: max(376, fittingSize.width),
            height: max(78, fittingSize.height)
        )
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = hostingView
        panel.setContentSize(panelSize)
        position(panel, size: panelSize)

        if wasVisible {
            panel.alphaValue = 1
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }

        scheduleDismissal(for: generation)
    }

    func dismiss() {
        displayGeneration += 1
        dismissalWorkItem?.cancel()
        dismissalWorkItem = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        hostingView = nil
    }

    private func perform(_ action: ClipboardActionDescriptor) {
        switch action.target {
        case .formatCode(let language, let source):
            formatterWindowManager.show(
                language: language,
                source: source,
                locale: SettingsManager.shared.resolvedLocale
            )
        case .copyText(let text):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        case .showReference(let reference):
            referenceWindowManager.show(
                reference,
                locale: SettingsManager.shared.resolvedLocale
            )
        case .external:
            ClipboardActionExecutor.perform(action)
        }
        dismiss()
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // The fixed NSWindow shadow hid the slider's visual range. The HUD now
        // draws a strength-aware shadow inside its transparent window instead.
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        self.panel = panel
        return panel
    }

    private var shouldUseNativeGlass: Bool {
        if #available(macOS 26.0, *) {
            return !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
        return false
    }

    private func position(_ panel: NSPanel, size: NSSize) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(
            HUDPositioning.origin(
                in: visibleFrame,
                panelSize: size,
                margin: screenMargin
            )
        )
    }

    private func scheduleDismissal(for generation: Int) {
        dismissalWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissIfCurrent(generation)
        }
        dismissalWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + currentDisplayDuration,
            execute: workItem
        )
    }

    private func displayDuration(for content: ClipboardContent) -> TimeInterval {
        switch content {
        case .englishWord:
            return 5.5
        case .chineseCharacter:
            return 4.0
        default:
            return defaultDisplayDuration
        }
    }

    private func handleHoverChanged(_ hovering: Bool) {
        dismissalWorkItem?.cancel()
        dismissalWorkItem = nil

        if !hovering, panel?.isVisible == true {
            scheduleDismissal(for: displayGeneration)
        }
    }

    private func dismissIfCurrent(_ generation: Int) {
        guard generation == displayGeneration, let panel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            MainActor.assumeIsolated {
                guard let self,
                      generation == self.displayGeneration,
                      let panel else { return }
                panel.orderOut(nil)
                panel.contentView = nil
                self.hostingView = nil
                self.dismissalWorkItem = nil
            }
        }
    }

}
