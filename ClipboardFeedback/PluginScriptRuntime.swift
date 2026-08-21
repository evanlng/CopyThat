import AppKit
import Foundation
import JavaScriptCore
import UniformTypeIdentifiers

enum PluginRuntimeError: LocalizedError, Equatable {
    case unavailable
    case permissionDenied(String)
    case invalidArgument
    case imageUnavailable
    case applicationUnavailable
    case scriptException(String)
    case missingEntryPoint

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The plugin runtime is unavailable."
        case .permissionDenied(let permission):
            return "The plugin does not have permission: \(permission)."
        case .invalidArgument: return "The plugin passed an invalid argument."
        case .imageUnavailable: return "The copied image is no longer available."
        case .applicationUnavailable: return "The requested application is not installed."
        case .scriptException(let message): return "Plugin error: \(message)"
        case .missingEntryPoint: return "The plugin must define function run(context)."
        }
    }
}

/// Runs only after a user clicks the plugin button. JavaScriptCore exposes no
/// filesystem, process, network, pasteboard, or AppKit API by default. These
/// permission-checked blocks are the complete CopyThat Host API v1 surface.
@MainActor
enum PluginScriptRuntime {
    static func perform(_ invocation: PluginScriptInvocation) throws {
        guard let context = JSContext() else { throw PluginRuntimeError.unavailable }

        var bridgeError: PluginRuntimeError?
        var scriptException: String?
        context.exceptionHandler = { _, exception in
            scriptException = exception?.toString() ?? "Unknown JavaScript exception"
        }

        let openCopiedContent: @convention(block) (String) -> Bool = { bundleIdentifier in
            guard invocation.permissions.contains(.openApplication) else {
                bridgeError = .permissionDenied(
                    DeclarativePluginPermission.openApplication.rawValue
                )
                return false
            }
            guard Self.validBundleIdentifier(bundleIdentifier) else {
                bridgeError = .invalidArgument
                return false
            }
            do {
                try CopiedContentApplicationBridge.open(
                    invocation.content,
                    permissions: invocation.permissions,
                    withBundleIdentifier: bundleIdentifier
                )
                return true
            } catch let error as PluginRuntimeError {
                bridgeError = error
                return false
            } catch {
                bridgeError = .invalidArgument
                return false
            }
        }

        let openHTTPS: @convention(block) (String) -> Bool = { rawURL in
            guard invocation.permissions.contains(.openHTTPS) else {
                bridgeError = .permissionDenied(
                    DeclarativePluginPermission.openHTTPS.rawValue
                )
                return false
            }
            guard let components = URLComponents(string: rawURL),
                  components.scheme?.lowercased() == "https",
                  components.host?.isEmpty == false,
                  components.user == nil,
                  components.password == nil,
                  let url = components.url else {
                bridgeError = .invalidArgument
                return false
            }
            return NSWorkspace.shared.open(url)
        }

        let writeText: @convention(block) (String) -> Bool = { text in
            guard invocation.permissions.contains(.writeText) else {
                bridgeError = .permissionDenied(
                    DeclarativePluginPermission.writeText.rawValue
                )
                return false
            }
            guard text.count <= 20_000 else {
                bridgeError = .invalidArgument
                return false
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)
        }

        context.setObject(
            openCopiedContent,
            forKeyedSubscript: "_copythatOpenCopiedContent" as NSString
        )
        context.setObject(openHTTPS, forKeyedSubscript: "_copythatOpenHTTPS" as NSString)
        context.setObject(writeText, forKeyedSubscript: "_copythatWriteText" as NSString)
        context.evaluateScript(#"""
        "use strict";
        const copythat = Object.freeze({
          hostAPIVersion: 1,
          openCopiedContent: function(bundleIdentifier) {
            return _copythatOpenCopiedContent(String(bundleIdentifier));
          },
          openHTTPS: function(url) {
            return _copythatOpenHTTPS(String(url));
          },
          writeText: function(text) {
            return _copythatWriteText(String(text));
          }
        });
        """#)
        context.evaluateScript(invocation.script)

        if let scriptException {
            throw PluginRuntimeError.scriptException(scriptException)
        }
        guard let run = context.objectForKeyedSubscript("run"),
              !run.isUndefined else {
            throw PluginRuntimeError.missingEntryPoint
        }

        var input: [String: Any] = ["kind": invocation.content.kind.rawValue]
        if invocation.permissions.contains(.readText),
           let text = invocation.content.textValue {
            input["text"] = text
        }
        _ = run.call(withArguments: [input])

        if let scriptException {
            throw PluginRuntimeError.scriptException(scriptException)
        }
        if let bridgeError { throw bridgeError }
    }

    private static func validBundleIdentifier(_ value: String) -> Bool {
        guard value.count <= 200, value.contains(".") else { return false }
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: ".-")
        )
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}

@MainActor
private enum CopiedContentApplicationBridge {
    private static let maximumImageBytes = 100 * 1_024 * 1_024
    private static let maximumTextCharacters = 20_000

    static func open(
        _ content: PluginContentInput,
        permissions: Set<DeclarativePluginPermission>,
        withBundleIdentifier bundleIdentifier: String
    ) throws {
        let workspace = NSWorkspace.shared
        guard let applicationURL = workspace.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            throw PluginRuntimeError.applicationUnavailable
        }

        let urls: [URL]
        switch content.kind {
        case .image:
            try require(.readImage, in: permissions)
            urls = [try materializeCurrentImage(
                expectedChangeCount: content.pasteboardChangeCount
            )]
        case .imageFiles:
            try require(.readFiles, in: permissions)
            guard !content.fileURLs.isEmpty else {
                throw PluginRuntimeError.invalidArgument
            }
            // Finder publishes a TIFF representation for a copied image file.
            // Prefer that sandbox-safe representation because the file URL does
            // not carry a lasting sandbox extension once it reaches the plugin.
            if let data = content.imageData,
               let fileExtension = content.imageFileExtension {
                urls = [try writeTemporary(data, fileExtension: fileExtension)]
            } else if content.fileURLs.count == 1,
               let imageURL = try? materializeCurrentImage(
                   expectedChangeCount: content.pasteboardChangeCount
               ) {
                urls = [imageURL]
            } else {
                urls = try content.fileURLs.prefix(20).map(materializeImageFile)
            }
        case .files:
            try require(.readFiles, in: permissions)
            guard !content.fileURLs.isEmpty else {
                throw PluginRuntimeError.invalidArgument
            }
            urls = Array(content.fileURLs.prefix(20))
        case .text, .calculation, .englishWord, .chineseCharacter,
                .link, .phoneNumber, .emailAddress, .code:
            try require(.readText, in: permissions)
            guard let text = content.textValue,
                  !text.isEmpty,
                  text.count <= maximumTextCharacters else {
                throw PluginRuntimeError.invalidArgument
            }
            urls = [try materializeText(text)]
        case .other:
            throw PluginRuntimeError.invalidArgument
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let accessedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        workspace.open(
            urls,
            withApplicationAt: applicationURL,
            configuration: configuration,
            completionHandler: { _, _ in
                accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            }
        )
    }

    private static func require(
        _ permission: DeclarativePluginPermission,
        in permissions: Set<DeclarativePluginPermission>
    ) throws {
        guard permissions.contains(permission) else {
            throw PluginRuntimeError.permissionDenied(permission.rawValue)
        }
    }

    private static func materializeCurrentImage(
        expectedChangeCount: Int?
    ) throws -> URL {
        let pasteboard = NSPasteboard.general
        guard expectedChangeCount == pasteboard.changeCount,
              let type = pasteboard.availableType(from: [.png, .tiff]),
              let data = pasteboard.data(forType: type),
              !data.isEmpty,
              data.count <= maximumImageBytes else {
            throw PluginRuntimeError.imageUnavailable
        }
        let fileExtension = type == .png ? "png" : "tiff"
        return try writeTemporary(data, fileExtension: fileExtension)
    }

    private static func materializeImageFile(_ sourceURL: URL) throws -> URL {
        guard sourceURL.isFileURL,
              let type = UTType(filenameExtension: sourceURL.pathExtension),
              type.conforms(to: .image) else {
            throw PluginRuntimeError.invalidArgument
        }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        guard !data.isEmpty, data.count <= maximumImageBytes else {
            throw PluginRuntimeError.imageUnavailable
        }
        return try writeTemporary(data, fileExtension: sourceURL.pathExtension)
    }

    private static func materializeText(_ text: String) throws -> URL {
        guard let data = text.data(using: .utf8) else {
            throw PluginRuntimeError.invalidArgument
        }
        return try writeTemporary(data, fileExtension: "txt")
    }

    private static func writeTemporary(
        _ data: Data,
        fileExtension: String
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CopyThat-PluginContent", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        removeExpiredContent(in: directory)

        let fileURL = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func removeExpiredContent(in directory: URL) {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in urls {
            guard let modified = try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate,
                  modified < cutoff else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
