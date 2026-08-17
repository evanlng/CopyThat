import Foundation
import XCTest
@testable import ClipboardFeedback

final class PluginArchitectureTests: XCTestCase {
    func testCalculatorEvaluatesBoundedExpressions() {
        XCTAssertEqual(
            MathExpressionEvaluator.evaluate("2 + 3 * 4"),
            .init(expression: "2 + 3 * 4", result: "14")
        )
        XCTAssertEqual(
            MathExpressionEvaluator.evaluate("2^3^2")?.result,
            "512"
        )
        XCTAssertEqual(
            MathExpressionEvaluator.evaluate("（6 + 1）×3")?.result,
            "21"
        )
    }

    func testCalculatorRejectsUnsafeOrMeaninglessInput() {
        XCTAssertNil(MathExpressionEvaluator.evaluate("42"))
        XCTAssertNil(MathExpressionEvaluator.evaluate("1 / 0"))
        XCTAssertNil(MathExpressionEvaluator.evaluate("sqrt(9)"))
        XCTAssertNil(MathExpressionEvaluator.evaluate(String(repeating: "1+", count: 100)))
    }

    func testCalculationDetectorCreatesCopyResultAction() {
        let content = CalculationContentDetector().detect(in: "12 * (3 + 4)")
        XCTAssertEqual(
            content,
            .calculation(expression: "12 * (3 + 4)", result: "84")
        )
        XCTAssertEqual(content?.primaryAction()?.title, "Copy Result")
        XCTAssertEqual(content?.primaryAction()?.target, .copyText("84"))
    }

    func testEnglishWordPluginUsesInjectedLocalDictionary() {
        let detector = EnglishWordContentDetector(
            definitions: StubDefinitions(values: [
                "swift": "moving or capable of moving at high speed"
            ])
        )
        XCTAssertEqual(
            detector.detect(in: "swift"),
            .englishWord(
                word: "swift",
                definition: "moving or capable of moving at high speed"
            )
        )
        XCTAssertNil(detector.detect(in: "unknown"))
    }

    func testSystemDictionaryIsAvailableInsideTheAppSandbox() {
        XCTAssertNotNil(SystemDictionaryProvider().definition(for: "apple"))
    }

    func testChineseCharacterPluginProducesPinyinAndDetailsAction() {
        let detector = ChineseCharacterContentDetector(
            definitions: StubDefinitions(values: ["马": "哺乳动物，善于奔跑。"])
        )
        guard case .chineseCharacter(
            let character,
            let pinyin,
            let definition
        ) = detector.detect(in: "马") else {
            return XCTFail("Expected one Chinese character")
        }

        XCTAssertEqual(character, "马")
        XCTAssertNotEqual(pinyin, "马")
        XCTAssertEqual(definition, "哺乳动物，善于奔跑。")

        let content = ClipboardContent.chineseCharacter(
            character: character,
            pinyin: pinyin,
            definition: definition
        )
        XCTAssertEqual(content.primaryAction()?.title, "Details")
    }

    func testActionPluginCanBeDisabledWithoutChangingHUDCode() {
        let content = ClipboardContent.link(URL(string: "https://example.com")!)
        let enabled = Set(ClipboardActionPluginID.allCases).subtracting([.openSafari])
        XCTAssertNil(content.primaryAction(enabledPluginIDs: enabled))
    }
}

private struct StubDefinitions: LocalDefinitionProviding {
    let values: [String: String]

    func definition(for term: String) -> String? {
        values[term]
    }
}
