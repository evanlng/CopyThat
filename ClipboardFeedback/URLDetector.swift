import Foundation

enum URLDetector {
    static func webURL(from rawValue: String) -> URL? {
        guard rawValue.count <= 2_048 else { return nil }
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              !candidate.contains(where: \Character.isNewline) else {
            return nil
        }

        // A copied browser address often omits its scheme. Treat only the
        // explicit www. form as a web URL so ordinary text such as file names or
        // sentence fragments does not become a false-positive link.
        let assumesHTTPS = candidate.lowercased().hasPrefix("www.")
        let normalizedCandidate = assumesHTTPS
            ? "https://" + candidate
            : candidate

        guard var components = URLComponents(string: normalizedCandidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        if assumesHTTPS {
            let domain = host.dropFirst(4)
            guard !domain.isEmpty,
                  domain.contains("."),
                  !host.hasSuffix(".") else {
                return nil
            }
        }

        // Normalize only the scheme. Preserve the path, query, and fragment used
        // when Safari opens the link.
        components.scheme = scheme
        return components.url
    }

    static func displayString(for url: URL, limit: Int = 110) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return TextPreview.make(url.absoluteString, limit: limit)
        }

        let portSuffix = components.port.map { ":\($0)" } ?? ""
        let decodedPath = components.percentEncodedPath.removingPercentEncoding
            ?? components.percentEncodedPath
        let path = decodedPath == "/" ? "" : decodedPath
        return TextPreview.make(host + portSuffix + path, limit: limit)
    }
}
