import Foundation

/// Safe, compile-time plugin point for adding content recognition. Detectors
/// run only after changeCount changes and must remain bounded and local.
protocol ClipboardContentDetector {
    var kind: ClipboardContentKind { get }
    func detect(in text: String) -> ClipboardContent?
}

struct ClipboardDetectionRegistry {
    static let builtIn = ClipboardDetectionRegistry(detectors: [
        LinkContentDetector(),
        EmailAddressContentDetector(),
        PhoneNumberContentDetector(),
        CalculationContentDetector(),
        ChineseCharacterContentDetector(),
        EnglishWordContentDetector(),
        CodeContentDetector()
    ])

    private let detectors: [any ClipboardContentDetector]

    init(detectors: [any ClipboardContentDetector]) {
        self.detectors = detectors
    }

    func detect(
        in text: String,
        enabledKinds: Set<ClipboardContentKind>
    ) -> ClipboardContent? {
        for detector in detectors where enabledKinds.contains(detector.kind) {
            if let content = detector.detect(in: text) {
                return content
            }
        }
        return nil
    }
}

struct CodeContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.code
    private let detector = CodeDetector()

    func detect(in text: String) -> ClipboardContent? {
        guard let language = detector.detectLanguage(in: text) else { return nil }
        let retainedSource: String?
        if language.supportsBasicFormatting,
           text.utf8.count <= CodeFormatter.maximumSourceBytes {
            retainedSource = text
        } else {
            retainedSource = nil
        }
        return .code(
            language: language,
            preview: TextPreview.make(text),
            source: retainedSource
        )
    }
}

struct LinkContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.link

    func detect(in text: String) -> ClipboardContent? {
        URLDetector.webURL(from: text).map(ClipboardContent.link)
    }
}

struct PhoneNumberContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.phoneNumber

    func detect(in text: String) -> ClipboardContent? {
        guard text.count <= 50 else { return nil }
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              candidate.count <= 40,
              !candidate.contains(where: \Character.isNewline) else {
            return nil
        }

        let permitted = CharacterSet.decimalDigits.union(
            CharacterSet(charactersIn: "+-(). ")
        )
        guard candidate.unicodeScalars.allSatisfy(permitted.contains) else {
            return nil
        }

        let digits = candidate.compactMap(\.wholeNumberValue).map(String.init).joined()
        let hasFormatting = candidate.first == "+"
            || candidate.contains(where: { "+-(). ".contains($0) })
        let minimumDigits = hasFormatting ? 7 : 10
        guard (minimumDigits...15).contains(digits.count) else { return nil }

        let normalized = candidate.first == "+" ? "+" + digits : digits
        return .phoneNumber(display: candidate, normalized: normalized)
    }
}

struct EmailAddressContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.emailAddress

    private static let expression = try! NSRegularExpression(
        pattern: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
        options: [.caseInsensitive]
    )

    func detect(in text: String) -> ClipboardContent? {
        guard text.count <= 300 else { return nil }
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= 254 else { return nil }
        let range = NSRange(candidate.startIndex..., in: candidate)
        guard Self.expression.firstMatch(
            in: candidate,
            options: [],
            range: range
        )?.range == range else {
            return nil
        }
        return .emailAddress(candidate)
    }
}
