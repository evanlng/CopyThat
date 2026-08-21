import AppKit
import Combine
import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct AppVersion: Comparable, Equatable, Sendable {
    let components: [Int]

    init?(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "v" || $0 == "V" })
        let parsed = normalized.split(separator: ".", omittingEmptySubsequences: false)
            .map { component -> Int? in
                let digits = component.prefix(while: \.isNumber)
                guard !digits.isEmpty else { return nil }
                return Int(digits)
            }
        guard !parsed.isEmpty, parsed.allSatisfy({ $0 != nil }) else { return nil }
        components = parsed.compactMap { $0 }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct GitHubReleaseAsset: Decodable, Equatable, Sendable {
    let name: String
    let downloadURL: URL
    let size: Int
    let digest: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
        case size
        case digest
    }
}

struct GitHubRelease: Decodable, Equatable, Sendable {
    let tagName: String
    let pageURL: URL
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
        case assets
    }

    var version: AppVersion? { AppVersion(tagName) }

    var preferredDMG: GitHubReleaseAsset? {
        let releaseVersion = tagName.drop(while: { $0 == "v" || $0 == "V" })
        let preferredNames = ["CopyThat.dmg", "CopyThat-\(releaseVersion).dmg"]
        for name in preferredNames {
            if let asset = assets.first(where: { $0.name == name }) {
                return asset
            }
        }
        return assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}

enum UpdateCheckError: LocalizedError, Sendable {
    case invalidResponse
    case invalidReleaseVersion
    case noDiskImage
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an invalid update response."
        case .invalidReleaseVersion:
            return "The latest GitHub release has an invalid version number."
        case .noDiskImage:
            return "The latest GitHub release does not contain a DMG file."
        case .checksumMismatch:
            return "The downloaded DMG does not match GitHub’s SHA-256 digest."
        }
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private enum Key {
        static let automaticChecks = "updates.automaticallyChecks"
        static let lastSuccessfulCheck = "updates.lastSuccessfulCheck"
    }

    private static let releaseAPI = URL(
        string: "https://api.github.com/repos/evanlng/CopyThat/releases/latest"
    )!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var canCheckForUpdates = true
    @Published private(set) var statusMessage: String?

    private let defaults: UserDefaults
    private let session: URLSession
    private var hasStarted = false
    private var isDownloading = false
    private var operationTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        self.automaticallyChecksForUpdates = defaults.bool(
            forKey: Key.automaticChecks
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        guard automaticallyChecksForUpdates, automaticCheckIsDue else { return }
        beginCheck(userInitiated: false)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        automaticallyChecksForUpdates = enabled
        defaults.set(enabled, forKey: Key.automaticChecks)
        if enabled, automaticCheckIsDue {
            beginCheck(userInitiated: false)
        }
    }

    func checkForUpdates() {
        beginCheck(userInitiated: true)
    }

    private var automaticCheckIsDue: Bool {
        guard let lastCheck = defaults.object(
            forKey: Key.lastSuccessfulCheck
        ) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastCheck) >= Self.checkInterval
    }

    private func beginCheck(userInitiated: Bool) {
        guard operationTask == nil else { return }
        canCheckForUpdates = false
        statusMessage = t("Checking GitHub for updates…", "正在检查 GitHub 更新…")
        operationTask = Task { [weak self] in
            await self?.performCheck(userInitiated: userInitiated)
        }
    }

    private func performCheck(userInitiated: Bool) async {
        defer {
            if !isDownloading {
                operationTask = nil
                canCheckForUpdates = true
            }
        }

        do {
            let release = try await Self.fetchLatestRelease(
                using: session,
                from: Self.releaseAPI
            )
            defaults.set(Date(), forKey: Key.lastSuccessfulCheck)

            guard let latestVersion = release.version else {
                throw UpdateCheckError.invalidReleaseVersion
            }
            let installedVersion = AppVersion(currentVersion) ?? AppVersion("0")!
            guard installedVersion < latestVersion else {
                statusMessage = t("CopyThat is up to date.", "CopyThat 已是最新版本。")
                if userInitiated {
                    showInformation(
                        title: t("You’re Up to Date", "已是最新版本"),
                        message: t(
                            "CopyThat \(currentVersion) is the newest available version.",
                            "CopyThat \(currentVersion) 已是当前最新版本。"
                        )
                    )
                }
                return
            }

            statusMessage = t(
                "Version \(release.tagName) is available.",
                "发现新版本 \(release.tagName)。"
            )
            presentAvailableUpdate(release)
        } catch {
            statusMessage = t("Could not check for updates.", "无法检查版本更新。")
            if userInitiated { showError(error) }
        }
    }

    private func presentAvailableUpdate(_ release: GitHubRelease) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = t(
            "CopyThat \(release.tagName) Is Available",
            "CopyThat \(release.tagName) 可供下载"
        )
        alert.informativeText = t(
            "CopyThat will download the GitHub DMG. Open it and drag CopyThat into Applications to finish updating.",
            "CopyThat 将下载 GitHub 上的 DMG。打开后，请将 CopyThat 拖入“应用程序”以完成更新。"
        )
        if release.preferredDMG != nil {
            alert.addButton(withTitle: t("Download DMG…", "下载 DMG…"))
        }
        alert.addButton(withTitle: t("View on GitHub", "在 GitHub 查看"))
        alert.addButton(withTitle: t("Later", "稍后"))

        let response = alert.runModal()
        if release.preferredDMG != nil, response == .alertFirstButtonReturn {
            chooseDownloadLocation(for: release)
        } else if response == (release.preferredDMG == nil
            ? .alertFirstButtonReturn
            : .alertSecondButtonReturn) {
            NSWorkspace.shared.open(release.pageURL)
        }
    }

    private func chooseDownloadLocation(for release: GitHubRelease) {
        guard let asset = release.preferredDMG else {
            showError(UpdateCheckError.noDiskImage)
            return
        }

        let panel = NSSavePanel()
        panel.title = t("Save CopyThat Update", "保存 CopyThat 更新包")
        panel.nameFieldStringValue = asset.name
        panel.allowedContentTypes = [.diskImage]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        canCheckForUpdates = false
        statusMessage = t("Downloading \(asset.name)…", "正在下载 \(asset.name)…")
        isDownloading = true
        operationTask = Task { [weak self] in
            await self?.download(asset, to: destination)
        }
    }

    private func download(_ asset: GitHubReleaseAsset, to destination: URL) async {
        defer {
            isDownloading = false
            operationTask = nil
            canCheckForUpdates = true
        }

        do {
            try await Self.downloadAsset(asset, to: destination, using: session)
            statusMessage = t("Download complete. Open the DMG to update.", "下载完成，请打开 DMG 更新。")
            NSWorkspace.shared.open(destination)
            showInformation(
                title: t("Download Complete", "下载完成"),
                message: t(
                    "The DMG has been opened. Drag CopyThat into Applications and choose Replace.",
                    "DMG 已打开。请将 CopyThat 拖入“应用程序”，并选择“替换”。"
                )
            )
        } catch {
            statusMessage = t("Update download failed.", "更新包下载失败。")
            showError(error)
        }
    }

    nonisolated static func fetchLatestRelease(
        using session: URLSession,
        from url: URL
    ) async throws -> GitHubRelease {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CopyThat-UpdateChecker", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateCheckError.invalidResponse
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    nonisolated static func downloadAsset(
        _ asset: GitHubReleaseAsset,
        to destination: URL,
        using session: URLSession
    ) async throws {
        var request = URLRequest(url: asset.downloadURL)
        request.setValue("CopyThat-UpdateChecker", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (temporaryURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.invalidResponse
        }

        if let expectedDigest = asset.digest,
           expectedDigest.lowercased().hasPrefix("sha256:") {
            let expected = String(expectedDigest.dropFirst("sha256:".count))
            let actual = try sha256(of: temporaryURL)
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                throw UpdateCheckError.checksumMismatch
            }
        }

        let didAccess = destination.startAccessingSecurityScopedResource()
        defer {
            if didAccess { destination.stopAccessingSecurityScopedResource() }
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: temporaryURL, to: destination)
    }

    nonisolated private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private var currentVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0"
    }

    private func showInformation(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: t("OK", "好"))
        alert.runModal()
    }

    private func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(error: error)
        alert.messageText = t("Software Update Failed", "软件更新失败")
        alert.runModal()
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, locale: SettingsManager.shared.resolvedLocale)
    }
}
