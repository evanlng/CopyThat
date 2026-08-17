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
           containsRegex(#"</?[a-z][^>]*>"#, in: lowercased) {
            scores[.html, default: 0] += 3
        }
        if lowercased.contains("</") {
            scores[.html, default: 0] += 2
        }

        if (lowercased.contains("def ") || lowercased.contains("class ")),
           containsRegex(#"(?m)^\s*(def|class)\s+[A-Za-z_]\w*"#, in: trimmed) {
            scores[.python, default: 0] += 5
        }
        if (lowercased.contains("import ") || lowercased.contains("from ")),
           containsRegex(#"(?m)^\s*(from\s+\S+\s+import|import\s+\S+)"#, in: trimmed) {
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
           containsRegex(#"(?m)^\s*import\s+(SwiftUI|Foundation|AppKit)"#, in: trimmed) {
            scores[.swift, default: 0] += 4
        }
        if ["func ", "struct ", "enum ", "protocol ", "extension "]
            .contains(where: trimmed.contains),
           containsRegex(#"\b(func|struct|enum|protocol|extension)\s+[A-Za-z_]\w*"#, in: trimmed) {
            scores[.swift, default: 0] += 4
        }
        if (trimmed.contains("let ") || trimmed.contains("var ")),
           containsRegex(#"\b(let|var)\s+[A-Za-z_]\w*\s*(?::|=)"#, in: trimmed) {
            scores[.swift, default: 0] += 1
        }
        if lowercased.contains("@main") || lowercased.contains("some view") {
            scores[.swift, default: 0] += 3
        }

        if trimmed.contains("="),
           (trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("var ")),
           containsRegex(#"\b(const|let|var)\s+[A-Za-z_$][\w$]*\s*="#, in: trimmed) {
            scores[.javaScript, default: 0] += 2
        }
        if lowercased.contains("function "),
           containsRegex(#"\bfunction\s+[A-Za-z_$][\w$]*\s*\("#, in: trimmed) {
            scores[.javaScript, default: 0] += 4
        }
        if trimmed.contains("=>") {
            scores[.javaScript, default: 0] += 4
        }
        if lowercased.contains("console.log(") {
            scores[.javaScript, default: 0] += 2
        }
        if (lowercased.contains("import ") || lowercased.contains("export ")),
           containsRegex(#"\b(import|export)\s+(default\s+)?"#, in: trimmed) {
            scores[.javaScript, default: 0] += 2
        }

        let cssProperties = [
            "color:", "background:", "display:", "margin:", "padding:",
            "font-size:", "width:", "height:", "border:"
        ]
        scores[.css, default: 0] += cssProperties.filter(lowercased.contains).count * 2
        if trimmed.contains("{"),
           containsRegex(#"(?m)^\s*([.#][A-Za-z_-][\w-]*|[A-Za-z][\w-]*)[^=\n]*\{"#, in: trimmed) {
            scores[.css, default: 0] += 3
        }
        if lowercased.contains("@media") || lowercased.contains("@keyframes") {
            scores[.css, default: 0] += 4
        }

        let sqlTokens = [
            "select ", " from ", "where ", "insert into ", "update ",
            "delete from ", "create table ", "alter table ", "join "
        ]
        scores[.sql, default: 0] += sqlTokens.filter { token in
            (" " + lowercased + " ").contains(token)
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
           containsRegex(#"(?m)^\s*(echo|printf|cd|export|source|curl|grep|sed|awk)\b"#, in: lowercased) {
            scores[.bash, default: 0] += 3
        }
        if lowercased.contains("${")
            || (trimmed.contains("$") && containsRegex(#"\$[A-Za-z_]\w*"#, in: trimmed)) {
            scores[.bash, default: 0] += 2
        }
        if (lowercased.contains("if ") || lowercased.contains("for ") || lowercased.contains("while ")),
           containsRegex(#"(?m)^\s*(if|for|while)\b.*;?\s*(then|do)?\s*$"#, in: lowercased) {
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

    private func containsRegex(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
