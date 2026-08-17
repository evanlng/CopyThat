import XCTest
@testable import ClipboardFeedback

final class URLDetectorTests: XCTestCase {
    func testAcceptsHTTPAndHTTPSURLs() {
        XCTAssertEqual(
            URLDetector.webURL(from: "https://www.apple.com/mac/"),
            URL(string: "https://www.apple.com/mac/")
        )
        XCTAssertEqual(
            URLDetector.webURL(from: "  http://example.com/article  "),
            URL(string: "http://example.com/article")
        )
        XCTAssertEqual(
            URLDetector.webURL(from: "www.apple.com/mac/"),
            URL(string: "https://www.apple.com/mac/")
        )
        XCTAssertEqual(
            URLDetector.webURL(from: "WWW.EXAMPLE.COM/article"),
            URL(string: "https://WWW.EXAMPLE.COM/article")
        )
    }

    func testRejectsUnsupportedOrPartialURLs() {
        XCTAssertNil(URLDetector.webURL(from: "ftp://example.com/file"))
        XCTAssertNil(URLDetector.webURL(from: "example.com/article"))
        XCTAssertNil(URLDetector.webURL(from: "not a URL"))
        XCTAssertNil(URLDetector.webURL(from: "www."))
        XCTAssertNil(URLDetector.webURL(from: "https://example.com\nmore text"))
    }

    func testDisplayStringHidesSchemeAndQuery() {
        let url = URL(string: "https://example.com/article?id=private#section")!
        XCTAssertEqual(URLDetector.displayString(for: url), "example.com/article")
    }
}
