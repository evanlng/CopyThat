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

struct ClipboardChangeGate {
    private var lastFingerprint: Int?

    mutating func reset(to content: ClipboardContent) {
        lastFingerprint = fingerprint(for: content)
    }

    mutating func shouldNotify(for content: ClipboardContent) -> Bool {
        guard let fingerprint = fingerprint(for: content) else {
            lastFingerprint = nil
            return true
        }
        guard fingerprint != lastFingerprint else { return false }
        lastFingerprint = fingerprint
        return true
    }

    private func fingerprint(for content: ClipboardContent) -> Int? {
        var hasher = Hasher()
        switch content {
        case .text(let text):
            hasher.combine(0); hasher.combine(text)
        case .calculation(let expression, let result):
            hasher.combine(1); hasher.combine(expression); hasher.combine(result)
        case .englishWord(let word, let definition):
            hasher.combine(2); hasher.combine(word); hasher.combine(definition)
        case .chineseCharacter(let character, let pinyin, let definition):
            hasher.combine(3); hasher.combine(character); hasher.combine(pinyin)
            hasher.combine(definition)
        case .link(let url):
            hasher.combine(4); hasher.combine(url)
        case .phoneNumber(let display, let normalized):
            hasher.combine(5); hasher.combine(display); hasher.combine(normalized)
        case .emailAddress(let email):
            hasher.combine(6); hasher.combine(email)
        case .code(let language, let preview, let source):
            hasher.combine(7); hasher.combine(language); hasher.combine(preview)
            hasher.combine(source)
        case .files(let urls, let totalCount):
            hasher.combine(8); hasher.combine(urls); hasher.combine(totalCount)
        case .image, .other:
            // A thumbnail is intentionally not retained or re-encoded merely
            // for deduplication. Preserve notifications for these uncommon
            // content kinds rather than risk suppressing a different image.
            return nil
        }
        return hasher.finalize()
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
    private var changeGate = ClipboardChangeGate()

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
        changeGate.reset(to: analyzeCurrentContent())
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

        let content = analyzeCurrentContent()
        guard changeGate.shouldNotify(for: content) else { return }
        onChange(content)
    }

    private func analyzeCurrentContent() -> ClipboardContent {
        analyzer.analyze(
            pasteboard,
            enabledKinds: enabledKindsProvider()
        )
    }
}
