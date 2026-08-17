import Foundation

enum CodeFormattingError: LocalizedError, Equatable {
    case unsupported
    case invalidJSON
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Basic formatting is currently available for JSON and Python."
        case .invalidJSON:
            return "The copied text is not valid JSON."
        case .tooLarge:
            return "This code is too large for the lightweight formatter."
        }
    }
}

enum CodeFormatter {
    static let maximumSourceBytes = 128 * 1_024

    static func format(
        _ source: String,
        language: CodeLanguage
    ) -> Result<String, CodeFormattingError> {
        guard source.utf8.count <= maximumSourceBytes else {
            return .failure(.tooLarge)
        }

        switch language {
        case .json:
            return formatJSON(source)
        case .python:
            return .success(formatPythonConservatively(source))
        default:
            return .failure(.unsupported)
        }
    }

    private static func formatJSON(
        _ source: String
    ) -> Result<String, CodeFormattingError> {
        guard let data = source.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let output = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .withoutEscapingSlashes]
              ),
              var formatted = String(data: output, encoding: .utf8) else {
            return .failure(.invalidJSON)
        }

        if !formatted.hasSuffix("\n") {
            formatted.append("\n")
        }
        return .success(formatted)
    }

    /// Python formatting is intentionally conservative: it normalizes line
    /// endings and removes trailing whitespace outside triple-quoted strings.
    /// Existing indentation is preserved to avoid changing program behavior.
    private static func formatPythonConservatively(_ source: String) -> String {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )

        var activeTripleQuote: String?
        var formattedLines: [String] = []
        formattedLines.reserveCapacity(lines.count)

        for lineSlice in lines {
            let line = String(lineSlice)
            let outputLine: String
            if activeTripleQuote == nil {
                outputLine = line.replacingOccurrences(
                    of: #"[ \t]+$"#,
                    with: "",
                    options: .regularExpression
                )
            } else {
                outputLine = line
            }
            formattedLines.append(outputLine)
            updateTripleQuoteState(in: line, active: &activeTripleQuote)
        }

        var result = formattedLines.joined(separator: "\n")
        while result.hasSuffix("\n\n") {
            result.removeLast()
        }
        if !result.isEmpty, !result.hasSuffix("\n") {
            result.append("\n")
        }
        return result
    }

    private static func updateTripleQuoteState(
        in line: String,
        active: inout String?
    ) {
        if let marker = active {
            if occurrenceCount(of: marker, in: line) % 2 == 1 {
                active = nil
            }
            return
        }

        for marker in ["\"\"\"", "'''"] where occurrenceCount(of: marker, in: line) % 2 == 1 {
            active = marker
            return
        }
    }

    private static func occurrenceCount(of marker: String, in text: String) -> Int {
        text.components(separatedBy: marker).count - 1
    }
}
