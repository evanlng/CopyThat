import XCTest
@testable import ClipboardFeedback

@MainActor
final class UpdateConfigurationTests: XCTestCase {
    func testVersionComparisonHandlesTagsAndMissingComponents() throws {
        XCTAssertLessThan(try XCTUnwrap(AppVersion("v3.0.9")), try XCTUnwrap(AppVersion("3.1")))
        XCTAssertEqual(AppVersion("3.1"), AppVersion("3.1.0"))
        XCTAssertEqual(AppVersion("V4.2.1-beta"), AppVersion("4.2.1"))
        XCTAssertNil(AppVersion("release"))
    }

    func testReleasePrefersStableDMGName() throws {
        let data = Data(#"""
        {
          "tag_name": "v3.1.0",
          "html_url": "https://github.com/evanlng/CopyThat/releases/tag/v3.1.0",
          "assets": [
            {
              "name": "CopyThat-3.1.0.dmg",
              "browser_download_url": "https://github.com/evanlng/CopyThat/releases/download/v3.1.0/CopyThat-3.1.0.dmg",
              "size": 7000000,
              "digest": "sha256:abc"
            },
            {
              "name": "CopyThat.dmg",
              "browser_download_url": "https://github.com/evanlng/CopyThat/releases/download/v3.1.0/CopyThat.dmg",
              "size": 7000000,
              "digest": "sha256:def"
            }
          ]
        }
        """#.utf8)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        XCTAssertEqual(release.version, AppVersion("3.1.0"))
        XCTAssertEqual(release.preferredDMG?.name, "CopyThat.dmg")
        XCTAssertEqual(release.preferredDMG?.digest, "sha256:def")
    }

    func testAutomaticChecksDefaultToOff() throws {
        let suiteName = "CopyThat.UpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = UpdateManager(defaults: defaults)

        XCTAssertFalse(manager.automaticallyChecksForUpdates)
        XCTAssertTrue(manager.canCheckForUpdates)
    }

    func testUpdaterHasOnlyUserSelectedWriteAndNetworkEntitlements() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(
            "ClipboardFeedback/ClipboardFeedback.entitlements"
        )
        let entitlements = try XCTUnwrap(
            NSDictionary(contentsOf: url) as? [String: Any]
        )

        XCTAssertEqual(entitlements["com.apple.security.network.client"] as? Bool, true)
        XCTAssertEqual(
            entitlements["com.apple.security.files.user-selected.read-write"] as? Bool,
            true
        )
        XCTAssertNil(entitlements["com.apple.security.cs.disable-library-validation"])
        XCTAssertNil(entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"])
    }
}
