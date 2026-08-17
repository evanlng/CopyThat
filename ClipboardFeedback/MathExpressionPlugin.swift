import Foundation

struct CalculationContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.calculation

    func detect(in text: String) -> ClipboardContent? {
        guard let calculation = MathExpressionEvaluator.evaluate(text) else {
            return nil
        }
        return .calculation(
            expression: calculation.expression,
            result: calculation.result
        )
    }
}

enum MathExpressionEvaluator {
    struct Calculation: Equatable {
        let expression: String
        let result: String
    }

    static func evaluate(_ source: String) -> Calculation? {
        let candidate = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")

        guard !candidate.isEmpty,
              candidate.count <= 160,
              !candidate.contains(where: \Character.isNewline),
              containsOperation(in: candidate),
              candidate.unicodeScalars.allSatisfy(isAllowed) else {
            return nil
        }

        var parser = Parser(candidate)
        guard let value = parser.parse(), value.isFinite else { return nil }
        return Calculation(expression: candidate, result: format(value))
    }

    private static func containsOperation(in text: String) -> Bool {
        text.contains { "+-*/%^()".contains($0) }
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.decimalDigits.contains(scalar)
            || CharacterSet.whitespaces.contains(scalar)
            || ".+-*/%^()eE".unicodeScalars.contains(scalar)
    }

    private static func format(_ value: Double) -> String {
        let normalized = abs(value) < 1e-12 ? 0 : value
        return String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), normalized)
    }

    private struct Parser {
        private let characters: [Character]
        private var index = 0
        private var depth = 0

        init(_ source: String) {
            self.characters = Array(source)
        }

        mutating func parse() -> Double? {
            guard let value = parseExpression() else { return nil }
            skipWhitespace()
            return index == characters.count ? value : nil
        }

        private mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while true {
                skipWhitespace()
                if consume("+") {
                    guard let right = parseTerm() else { return nil }
                    value += right
                } else if consume("-") {
                    guard let right = parseTerm() else { return nil }
                    value -= right
                } else {
                    return value
                }
                guard value.isFinite else { return nil }
            }
        }

        private mutating func parseTerm() -> Double? {
            guard var value = parsePower() else { return nil }
            while true {
                skipWhitespace()
                if consume("*") {
                    guard let right = parsePower() else { return nil }
                    value *= right
                } else if consume("/") {
                    guard let right = parsePower(), right != 0 else { return nil }
                    value /= right
                } else if consume("%") {
                    guard let right = parsePower(), right != 0 else { return nil }
                    value.formTruncatingRemainder(dividingBy: right)
                } else {
                    return value
                }
                guard value.isFinite else { return nil }
            }
        }

        private mutating func parsePower() -> Double? {
            guard let base = parseUnary() else { return nil }
            skipWhitespace()
            guard consume("^") else { return base }
            guard let exponent = parsePower() else { return nil }
            let value = Foundation.pow(base, exponent)
            return value.isFinite ? value : nil
        }

        private mutating func parseUnary() -> Double? {
            skipWhitespace()
            if consume("+") { return parseUnary() }
            if consume("-") { return parseUnary().map(-) }
            return parsePrimary()
        }

        private mutating func parsePrimary() -> Double? {
            skipWhitespace()
            if consume("(") {
                guard depth < 24 else { return nil }
                depth += 1
                defer { depth -= 1 }
                guard let value = parseExpression() else { return nil }
                skipWhitespace()
                guard consume(")") else { return nil }
                return value
            }
            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            skipWhitespace()
            let start = index
            var hasDigit = false
            var hasDecimalPoint = false

            while index < characters.count {
                let character = characters[index]
                if character.isNumber {
                    hasDigit = true
                    index += 1
                } else if character == ".", !hasDecimalPoint {
                    hasDecimalPoint = true
                    index += 1
                } else {
                    break
                }
            }
            guard hasDigit else { return nil }

            if index < characters.count,
               characters[index] == "e" || characters[index] == "E" {
                let exponentStart = index
                index += 1
                if index < characters.count,
                   characters[index] == "+" || characters[index] == "-" {
                    index += 1
                }
                let digitsStart = index
                while index < characters.count, characters[index].isNumber {
                    index += 1
                }
                if digitsStart == index {
                    index = exponentStart
                }
            }

            return Double(String(characters[start..<index]))
        }

        private mutating func skipWhitespace() {
            while index < characters.count, characters[index].isWhitespace {
                index += 1
            }
        }

        private mutating func consume(_ expected: Character) -> Bool {
            guard index < characters.count, characters[index] == expected else {
                return false
            }
            index += 1
            return true
        }
    }
}
