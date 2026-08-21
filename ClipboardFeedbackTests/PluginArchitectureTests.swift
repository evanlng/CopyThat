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

    func testEnglishAndChineseInterfaceStringsAreExplicit() {
        XCTAssertEqual(
            ClipboardContent.link(URL(string: "https://example.com")!)
                .title(in: .english),
            "Link copied"
        )
        XCTAssertEqual(
            ClipboardContent.link(URL(string: "https://example.com")!)
                .title(in: .simplifiedChinese),
            "链接已复制"
        )
        XCTAssertEqual(
            ClipboardActionPluginID.copyCalculation.title(in: .simplifiedChinese),
            "复制结果"
        )
    }

    func testDeclarativePluginCreatesAnEncodedHTTPSAction() throws {
        let manifest = try DeclarativePluginCodec.decodeAndValidate(Data(#"""
        {
          "schemaVersion": 1,
          "identifier": "com.copythat.example.maps",
          "name": { "en": "Maps Search", "zh-Hans": "地图搜索" },
          "description": { "en": "Find copied text in Maps.", "zh-Hans": "在地图中查找复制文字。" },
          "systemImage": "map",
          "matches": ["text"],
          "action": {
            "type": "openURL",
            "title": { "en": "Find Place", "zh-Hans": "查找位置" },
            "urlTemplate": "https://maps.apple.com/?q={content}"
          }
        }
        """#.utf8))

        let action = ClipboardContent.text("coffee shop").primaryAction(
            locale: .simplifiedChinese,
            declarativePlugins: [manifest]
        )
        XCTAssertEqual(action?.title, "查找位置")
        XCTAssertEqual(
            action?.target,
            .external(.openDefault(URL(string: "https://maps.apple.com/?q=coffee%20shop")!))
        )
    }

    func testDeclarativePluginRejectsUnsafeURLSchemes() {
        let data = Data(#"""
        {
          "schemaVersion": 1,
          "identifier": "com.copythat.example.unsafe",
          "name": { "en": "Unsafe" },
          "description": { "en": "Unsafe action." },
          "systemImage": "bolt",
          "matches": ["text"],
          "action": {
            "type": "openURL",
            "title": { "en": "Run" },
            "urlTemplate": "http://example.com/?q={content}"
          }
        }
        """#.utf8)

        XCTAssertThrowsError(try DeclarativePluginCodec.decodeAndValidate(data)) {
            XCTAssertEqual(
                $0 as? DeclarativePluginValidationError,
                .unsafeURLTemplate
            )
        }
    }

    func testScriptPluginCreatesImageInvocationThroughHostAPI() throws {
        let manifest = try DeclarativePluginCodec.decodeAndValidate(Data(#"""
        {
          "schemaVersion": 2,
          "minimumHostAPIVersion": 1,
          "identifier": "com.copythat.tests.preview",
          "name": { "en": "Edit in Preview" },
          "description": { "en": "Open copied images in Preview." },
          "systemImage": "pencil.and.scribble",
          "matches": ["image"],
          "permissions": ["clipboard.readImage", "system.openApplication"],
          "action": {
            "type": "runScript",
            "title": { "en": "Edit in Preview" }
          },
          "script": "function run(context) { return copythat.openCopiedContent('com.apple.Preview'); }"
        }
        """#.utf8))

        let action = ClipboardContent.image(thumbnail: nil).primaryAction(
            declarativePlugins: [manifest]
        )
        guard case .runPlugin(let invocation) = action?.target else {
            return XCTFail("Expected a script plugin action")
        }
        XCTAssertEqual(action?.title, "Edit in Preview")
        XCTAssertEqual(invocation.identifier, "com.copythat.tests.preview")
        XCTAssertEqual(invocation.content.kind, .image)
        XCTAssertTrue(invocation.permissions.contains(.readImage))
        XCTAssertTrue(invocation.permissions.contains(.openApplication))
    }

    func testV1PluginsRemainCompatibleWithSchemaV2Host() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Examples/OpenInMaps.copythatplugin"))
        let manifest = try DeclarativePluginCodec.decodeAndValidate(data)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.action.type, .openURL)
    }

    func testEditInPreviewExampleIsInstallable() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Examples/EditInPreview.copythatplugin"))
        let manifest = try DeclarativePluginCodec.decodeAndValidate(data)
        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertEqual(manifest.minimumHostAPIVersion, 1)
        XCTAssertEqual(manifest.matches, [.image])
        XCTAssertEqual(
            Set(manifest.permissions ?? []),
            [.readImage, .openApplication]
        )
        XCTAssertEqual(manifest.action.type, .runScript)
    }

    func testScriptPluginRejectsDuplicatePermissions() {
        let data = Data(#"""
        {
          "schemaVersion": 2,
          "minimumHostAPIVersion": 1,
          "identifier": "com.copythat.tests.duplicate",
          "name": { "en": "Duplicate" },
          "description": { "en": "Duplicate permissions." },
          "systemImage": "puzzlepiece",
          "matches": ["text"],
          "permissions": ["clipboard.readText", "clipboard.readText"],
          "action": { "type": "runScript", "title": { "en": "Run" } },
          "script": "function run(context) {}"
        }
        """#.utf8)

        XCTAssertThrowsError(try DeclarativePluginCodec.decodeAndValidate(data)) {
            XCTAssertEqual(
                $0 as? DeclarativePluginValidationError,
                .invalidPermissions
            )
        }
    }

    @MainActor
    func testRuntimeEnforcesPermissionOnEveryHostCall() {
        let invocation = PluginScriptInvocation(
            identifier: "com.copythat.tests.permissions",
            script: "function run(context) { copythat.writeText('blocked'); }",
            permissions: [],
            content: PluginContentInput(kind: .text, textValue: "input")
        )
        XCTAssertThrowsError(try PluginScriptRuntime.perform(invocation)) {
            XCTAssertEqual(
                $0 as? PluginRuntimeError,
                .permissionDenied(DeclarativePluginPermission.writeText.rawValue)
            )
        }
    }

    @MainActor
    func testPluginsCanBeRemovedAndInstalledWithoutLosingTheCatalog() {
        let suiteName = "CopyThat.PluginArchitectureTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(defaults: defaults)
        XCTAssertTrue(settings.isDetectionInstalled(.calculation))
        XCTAssertTrue(settings.enabledDetectionKinds.contains(.calculation))

        settings.uninstallDetectionPlugin(.calculation)
        XCTAssertFalse(settings.isDetectionInstalled(.calculation))
        XCTAssertFalse(settings.enabledDetectionKinds.contains(.calculation))

        settings.installDetectionPlugin(.calculation)
        XCTAssertTrue(settings.isDetectionInstalled(.calculation))
        XCTAssertTrue(settings.isDetectionEnabled(.calculation))

        settings.uninstallActionPlugin(.copyCalculation)
        XCTAssertFalse(settings.enabledActionPluginIDs.contains(.copyCalculation))

        settings.installActionPlugin(.copyCalculation)
        XCTAssertTrue(settings.isActionPluginEnabled(.copyCalculation))

        settings.appLanguage = .simplifiedChinese
        let reloaded = SettingsManager(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .simplifiedChinese)
        XCTAssertTrue(reloaded.isDetectionInstalled(.calculation))
        XCTAssertTrue(reloaded.isActionPluginInstalled(.copyCalculation))
    }

    @MainActor
    func testDeclarativePluginCanBeInstalledReloadedDisabledAndRemoved() throws {
        let suiteName = "CopyThat.DeclarativePluginTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CopyThatTests-\(UUID().uuidString)", isDirectory: true)
        let pluginDirectory = root.appendingPathComponent("Installed", isDirectory: true)
        let sourceURL = root.appendingPathComponent("Maps.copythatplugin")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(#"""
        {
          "schemaVersion": 1,
          "identifier": "com.copythat.tests.maps",
          "name": { "en": "Maps" },
          "description": { "en": "Find copied text." },
          "systemImage": "map",
          "matches": ["text"],
          "action": {
            "type": "openURL",
            "title": { "en": "Open Maps" },
            "urlTemplate": "https://maps.apple.com/?q={content}"
          }
        }
        """#.utf8).write(to: sourceURL)

        let settings = SettingsManager(
            defaults: defaults,
            declarativePluginDirectory: pluginDirectory
        )
        let installed = try settings.installDeclarativePlugin(from: sourceURL)
        XCTAssertEqual(settings.enabledDeclarativePlugins.map(\.identifier), [installed.identifier])

        settings.setDeclarativePlugin(installed, enabled: false)
        XCTAssertTrue(settings.enabledDeclarativePlugins.isEmpty)

        let reloaded = SettingsManager(
            defaults: defaults,
            declarativePluginDirectory: pluginDirectory
        )
        XCTAssertEqual(reloaded.installedDeclarativePlugins.map(\.identifier), [installed.identifier])
        XCTAssertTrue(reloaded.enabledDeclarativePlugins.isEmpty)

        try reloaded.uninstallDeclarativePlugin(installed)
        XCTAssertTrue(reloaded.installedDeclarativePlugins.isEmpty)
    }
}

private struct StubDefinitions: LocalDefinitionProviding {
    let values: [String: String]

    func definition(for term: String) -> String? {
        values[term]
    }
}
