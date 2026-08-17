import XCTest
@testable import ClipboardFeedback

final class CodeDetectorTests: XCTestCase {
    private let detector = CodeDetector()

    func testDetectsSupportedLanguages() {
        let samples: [(CodeLanguage, String)] = [
            (.python, "def greet(name):\n    print(f\"Hello {name}\")"),
            (.javaScript, "const greet = (name) => {\n  console.log(name);\n};"),
            (.swift, "import SwiftUI\nstruct Card: View {\n var body: some View { Text(\"Hi\") }\n}"),
            (.html, "<!doctype html>\n<html><body><h1>Hello</h1></body></html>"),
            (.css, ".card {\n  color: red;\n  padding: 8px;\n}"),
            (.json, #"{"name":"Clipboard","enabled":true}"#),
            (.sql, "SELECT name\nFROM users\nWHERE enabled = 1;"),
            (.bash, "#!/usr/bin/env bash\nfor file in *; do\n  echo \"$file\"\ndone")
        ]

        for (language, source) in samples {
            XCTAssertEqual(
                detector.detectLanguage(in: source),
                language,
                "Failed to detect \(language.title)"
            )
        }
    }

    func testRejectsOrdinaryProse() {
        XCTAssertNil(detector.detectLanguage(in: "Please select a file from Finder."))
        XCTAssertNil(detector.detectLanguage(in: "This is an ordinary copied sentence."))
    }
}
