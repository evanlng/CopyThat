import AppKit

struct ClipboardMonitorConfiguration: Equatable {
    let idleInterval: TimeInterval
    let activeInterval: TimeInterval
    let activeDuration: TimeInterval

    static let responsive = ClipboardMonitorConfiguration(
        idleInterval: 0.25,
        activeInterval: 0.08,
        activeDuration: 2.4
    )
}

@MainActor
final class ClipboardMonitor {
    typealias ChangeHandler = @MainActor (ClipboardContent) -> Void

    private let pasteboard: NSPasteboard
    private let configuration: ClipboardMonitorConfiguration
    private let analyzer: ClipboardAnalyzer
    private let enabledKindsProvider: @MainActor () -> Set<ClipboardContentKind>
    private let onChange: ChangeHandler
    private var lastChangeCount: Int
    private var timer: Timer?
    private var activeUntil: Date?
    private var currentInterval: TimeInterval?

    init(
        pasteboard: NSPasteboard = .general,
        configuration: ClipboardMonitorConfiguration = .responsive,
        analyzer: ClipboardAnalyzer = ClipboardAnalyzer(),
        enabledKindsProvider: @escaping @MainActor () -> Set<ClipboardContentKind> = {
            Set(ClipboardContentKind.allCases)
        },
        onChange: @escaping ChangeHandler
    ) {
        self.pasteboard = pasteboard
        self.configuration = configuration
        self.analyzer = analyzer
        self.enabledKindsProvider = enabledKindsProvider
        self.onChange = onChange
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        lastChangeCount = pasteboard.changeCount
        activeUntil = nil
        installTimer(interval: configuration.idleInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentInterval = nil
        activeUntil = nil
    }

    private func installTimer(interval: TimeInterval) {
        guard currentInterval != interval else { return }
        timer?.invalidate()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        timer.tolerance = interval == configuration.idleInterval
            ? min(0.04, interval * 0.2)
            : min(0.015, interval * 0.2)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        currentInterval = interval
    }

    private func poll() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            if let activeUntil, Date() >= activeUntil {
                self.activeUntil = nil
                installTimer(interval: configuration.idleInterval)
            }
            return
        }

        lastChangeCount = currentChangeCount
        activeUntil = Date().addingTimeInterval(configuration.activeDuration)
        installTimer(interval: configuration.activeInterval)

        // The monitor retains no content after handing off this one analysis.
        onChange(analyzer.analyze(
            pasteboard,
            enabledKinds: enabledKindsProvider()
        ))
    }
}
