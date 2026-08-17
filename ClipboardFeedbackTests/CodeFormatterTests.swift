import XCTest
@testable import ClipboardFeedback

final class CodeFormatterTests: XCTestCase {
    func testPrettyPrintsJSON() throws {
        let result = CodeFormatter.format(#"{"name":"Copy","items":[1,2]}"#, language: .json)
        let formatted = try result.get()

        XCTAssertTrue(formatted.contains("\"name\" : \"Copy\""))
        XCTAssertTrue(formatted.contains("\n"))
        XCTAssertTrue(formatted.hasSuffix("\n"))
    }

    func testPythonFormattingPreservesIndentationAndRemovesTrailingSpace() throws {
        let source = "def greet():  \r\n    print(\"hello\")   \r\n"
        let formatted = try CodeFormatter.format(source, language: .python).get()

        XCTAssertEqual(formatted, "def greet():\n    print(\"hello\")\n")
    }

    func testDoesNotFormatUnsupportedLanguage() {
        XCTAssertEqual(
            CodeFormatter.format("const value = 1;", language: .javaScript),
            .failure(.unsupported)
        )
    }
}
