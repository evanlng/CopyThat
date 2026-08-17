import AppKit

struct ClipboardMonitorConfiguration: Equatable {
    let idleInterval: TimeInterval
    let activeInterval: TimeInterval
    let activeDuration: TimeInterval

    static let responsive = ClipboardMonitorConfiguration(
        idleInterval: 0.25,
        activeInterval: 0.06,
        activeDuration: 0.9
    )

    var activePollLimit: Int {
        guard activeInterval > 0, activeDuration > 0 else { return 1 }
        return max(1, Int((activeDuration / activeInterval).rounded()))
    }
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
    private var remainingActivePolls = 0
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
        remainingActivePolls = 0
        installTimer(interval: configuration.idleInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentInterval = nil
        remainingActivePolls = 0
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
            : min(0.012, interval * 0.2)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        currentInterval = interval
    }

    private func poll() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            if currentInterval == configuration.activeInterval,
               remainingActivePolls > 0 {
                remainingActivePolls -= 1
            }
            if currentInterval == configuration.activeInterval,
               remainingActivePolls == 0 {
                installTimer(interval: configuration.idleInterval)
            }
            return
        }

        lastChangeCount = currentChangeCount
        remainingActivePolls = configuration.activePollLimit
        installTimer(interval: configuration.activeInterval)

        // The monitor retains no content after handing off this one analysis.
        onChange(analyzer.analyze(
            pasteboard,
            enabledKinds: enabledKindsProvider()
        ))
    }
}
