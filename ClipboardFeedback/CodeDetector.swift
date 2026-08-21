import Foundation

enum CodeLanguage: String, CaseIterable, Equatable, Hashable, Identifiable {
    case python
    case javaScript
    case swift
    case html
    case css
    case json
    case sql
    case bash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .python: return "Python"
        case .javaScript: return "JavaScript"
        case .swift: return "Swift"
        case .html: return "HTML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .sql: return "SQL"
        case .bash: return "Bash"
        }
    }

    var supportsBasicFormatting: Bool {
        self == .json || self == .python
    }
}

/// Lightweight, deterministic code recognition. Only a bounded prefix is
/// inspected, and no syntax tree, compiler, network service, or cache is used.
struct CodeDetector {
    private static let analysisLimit = 20_000

    private enum Pattern {
        static let htmlTag = regex(#"</?[a-z][^>]*>"#)
        static let pythonDeclaration = regex(#"(?m)^\s*(def|class)\s+[A-Za-z_]\w*"#)
        static let pythonImport = regex(#"(?m)^\s*(from\s+\S+\s+import|import\s+\S+)"#)
        static let swiftImport = regex(#"(?m)^\s*import\s+(SwiftUI|Foundation|AppKit)"#)
        static let swiftDeclaration = regex(#"\b(func|struct|enum|protocol|extension)\s+[A-Za-z_]\w*"#)
        static let swiftBinding = regex(#"\b(let|var)\s+[A-Za-z_]\w*\s*(?::|=)"#)
        static let javaScriptBinding = regex(#"\b(const|let|var)\s+[A-Za-z_$][\w$]*\s*="#)
        static let javaScriptFunction = regex(#"\bfunction\s+[A-Za-z_$][\w$]*\s*\("#)
        static let javaScriptImport = regex(#"\b(import|export)\s+(default\s+)?"#)
        static let cssSelector = regex(#"(?m)^\s*([.#][A-Za-z_-][\w-]*|[A-Za-z][\w-]*)[^=\n]*\{"#)
        static let bashCommand = regex(#"(?m)^\s*(echo|printf|cd|export|source|curl|grep|sed|awk)\b"#)
        static let bashVariable = regex(#"\$[A-Za-z_]\w*"#)
        static let bashControl = regex(#"(?m)^\s*(if|for|while)\b.*;?\s*(then|do)?\s*$"#)

        private static func regex(_ pattern: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: pattern)
        }
    }

    func detectLanguage(in source: String) -> CodeLanguage? {
        let sample = String(source.prefix(Self.analysisLimit))
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        if isJSONObjectOrArray(trimmed) {
            return .json
        }

        let lowercased = trimmed.lowercased()
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        let hasMultipleLines = lines.count > 1
        let indentationCount = lines.lazy.filter { line in
            line.hasPrefix("  ") || line.hasPrefix("\t")
        }.count

        var scores: [CodeLanguage: Int] = [:]

        if lowercased.contains("<!doctype html") || lowercased.contains("<html") {
            scores[.html, default: 0] += 6
        }
        if lowercased.contains("<"), lowercased.contains(">"),
           containsRegex(Pattern.htmlTag, in: lowercased) {
            scores[.html, default: 0] += 3
        }
        if lowercased.contains("</") {
            scores[.html, default: 0] += 2
        }

        if (lowercased.contains("def ") || lowercased.contains("class ")),
           containsRegex(Pattern.pythonDeclaration, in: trimmed) {
            scores[.python, default: 0] += 5
        }
        if (lowercased.contains("import ") || lowercased.contains("from ")),
           containsRegex(Pattern.pythonImport, in: trimmed) {
            scores[.python, default: 0] += 2
        }
        if lowercased.contains("if __name__ ==") {
            scores[.python, default: 0] += 4
        }
        if lowercased.contains("print(") {
            scores[.python, default: 0] += 1
        }
        if lines.contains(where: {
            String($0).trimmingCharacters(in: .whitespaces).hasSuffix(":")
        }) {
            scores[.python, default: 0] += 1
        }

        if trimmed.contains("import "),
           containsRegex(Pattern.swiftImport, in: trimmed) {
            scores[.swift, default: 0] += 4
        }
        if ["func ", "struct ", "enum ", "protocol ", "extension "]
            .contains(where: trimmed.contains),
           containsRegex(Pattern.swiftDeclaration, in: trimmed) {
            scores[.swift, default: 0] += 4
        }
        if (trimmed.contains("let ") || trimmed.contains("var ")),
           containsRegex(Pattern.swiftBinding, in: trimmed) {
            scores[.swift, default: 0] += 1
        }
        if lowercased.contains("@main") || lowercased.contains("some view") {
            scores[.swift, default: 0] += 3
        }

        if trimmed.contains("="),
           (trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("var ")),
           containsRegex(Pattern.javaScriptBinding, in: trimmed) {
            scores[.javaScript, default: 0] += 2
        }
        if lowercased.contains("function "),
           containsRegex(Pattern.javaScriptFunction, in: trimmed) {
            scores[.javaScript, default: 0] += 4
        }
        if trimmed.contains("=>") {
            scores[.javaScript, default: 0] += 4
        }
        if lowercased.contains("console.log(") {
            scores[.javaScript, default: 0] += 2
        }
        if (lowercased.contains("import ") || lowercased.contains("export ")),
           containsRegex(Pattern.javaScriptImport, in: trimmed) {
            scores[.javaScript, default: 0] += 2
        }

        let cssProperties = [
            "color:", "background:", "display:", "margin:", "padding:",
            "font-size:", "width:", "height:", "border:"
        ]
        scores[.css, default: 0] += cssProperties.filter(lowercased.contains).count * 2
        if trimmed.contains("{"),
           containsRegex(Pattern.cssSelector, in: trimmed) {
            scores[.css, default: 0] += 3
        }
        if lowercased.contains("@media") || lowercased.contains("@keyframes") {
            scores[.css, default: 0] += 4
        }

        let sqlTokens = [
            "select ", " from ", "where ", "insert into ", "update ",
            "delete from ", "create table ", "alter table ", "join "
        ]
        let paddedLowercased = " \(lowercased) "
        scores[.sql, default: 0] += sqlTokens.filter { token in
            paddedLowercased.contains(token)
        }.count * 2
        if trimmed.contains(";") {
            scores[.sql, default: 0] += 1
        }

        if lowercased.hasPrefix("#!/bin/bash") || lowercased.hasPrefix("#!/bin/sh")
            || lowercased.hasPrefix("#!/usr/bin/env bash") {
            scores[.bash, default: 0] += 7
        }
        if ["echo ", "printf ", "cd ", "export ", "source ", "curl ", "grep ", "sed ", "awk "]
            .contains(where: lowercased.contains),
           containsRegex(Pattern.bashCommand, in: lowercased) {
            scores[.bash, default: 0] += 3
        }
        if lowercased.contains("${")
            || (trimmed.contains("$") && containsRegex(Pattern.bashVariable, in: trimmed)) {
            scores[.bash, default: 0] += 2
        }
        if (lowercased.contains("if ") || lowercased.contains("for ") || lowercased.contains("while ")),
           containsRegex(Pattern.bashControl, in: lowercased) {
            scores[.bash, default: 0] += 2
        }

        if hasMultipleLines && indentationCount > 0 {
            scores[.python, default: 0] += 1
            scores[.swift, default: 0] += 1
            scores[.javaScript, default: 0] += 1
        }
        if trimmed.contains("{") && trimmed.contains("}") {
            scores[.swift, default: 0] += 1
            scores[.javaScript, default: 0] += 1
            scores[.css, default: 0] += 1
        }

        let priority: [CodeLanguage] = [
            .html, .python, .swift, .javaScript, .css, .sql, .bash
        ]
        let best = priority.max { lhs, rhs in
            scores[lhs, default: 0] < scores[rhs, default: 0]
        }
        guard let best else { return nil }
        let threshold = best == .sql ? 5 : 4
        guard scores[best, default: 0] >= threshold else { return nil }
        return best
    }

    private func isJSONObjectOrArray(_ text: String) -> Bool {
        guard let first = text.first,
              let last = text.last,
              (first == "{" && last == "}") || (first == "[" && last == "]"),
              let data = text.data(using: .utf8),
              data.count <= 256_000 else {
            return false
        }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func containsRegex(
        _ expression: NSRegularExpression,
        in text: String
    ) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }
}
