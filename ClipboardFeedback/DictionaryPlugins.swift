import CoreServices
import Foundation

protocol LocalDefinitionProviding: Sendable {
    func definition(for term: String) -> String?
}

/// Uses the dictionaries already installed by macOS. It performs no network
/// access and is called only after a clipboard change contains one short term.
struct SystemDictionaryProvider: LocalDefinitionProviding {
    private static let maximumDefinitionLength = 320

    func definition(for term: String) -> String? {
        let range = CFRange(location: 0, length: term.utf16.count)
        guard let copied = DCSCopyTextDefinition(nil, term as CFString, range) else {
            return nil
        }
        let definition = copied.takeRetainedValue() as String
        let compact = definition
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        guard !compact.isEmpty else { return nil }
        return String(compact.prefix(Self.maximumDefinitionLength))
    }
}

struct EnglishWordContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.englishWord
    private static let wordExpression = try! NSRegularExpression(
        pattern: #"^[A-Za-z]+(?:['’-][A-Za-z]+)*$"#
    )
    private let definitions: any LocalDefinitionProviding

    init(definitions: any LocalDefinitionProviding = SystemDictionaryProvider()) {
        self.definitions = definitions
    }

    func detect(in text: String) -> ClipboardContent? {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...48).contains(word.count) else { return nil }
        let range = NSRange(word.startIndex..<word.endIndex, in: word)
        guard Self.wordExpression.firstMatch(in: word, range: range)?.range == range,
              let definition = definitions.definition(for: word) else {
            return nil
        }
        return .englishWord(word: word, definition: definition)
    }
}

struct ChineseCharacterContentDetector: ClipboardContentDetector {
    let kind = ClipboardContentKind.chineseCharacter
    private let definitions: any LocalDefinitionProviding

    init(definitions: any LocalDefinitionProviding = SystemDictionaryProvider()) {
        self.definitions = definitions
    }

    func detect(in text: String) -> ClipboardContent? {
        let character = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard character.count == 1,
              let scalar = character.unicodeScalars.first,
              isHan(scalar) else {
            return nil
        }
        return .chineseCharacter(
            character: character,
            pinyin: pinyin(for: character),
            definition: definitions.definition(for: character)
        )
    }

    private func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2EBEF:
            return true
        default:
            return false
        }
    }

    private func pinyin(for character: String) -> String {
        let mutable = NSMutableString(string: character)
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        let value = mutable as String
        return value.isEmpty || value == character ? "Pinyin unavailable" : value
    }
}
