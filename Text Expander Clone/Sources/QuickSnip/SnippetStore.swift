import Foundation

struct Snippet {
    var abbreviation: String
    var label: String
    var plainText: String
    var richText: Data?
    var type: Int          // 0 = plain, 1 = rich text, 2 = picture (skipped)
    var abbreviationMode: Int  // 0 = case-insensitive, 2 = case-sensitive

    var displayPreview: String {
        plainText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

class SnippetStore {
    private(set) var snippets: [Snippet] = []
    private var caseInsensitiveIndex: [String: Snippet] = [:]  // lowercased abbrev → snippet
    private var caseSensitiveIndex: [String: Snippet] = [:]    // exact abbrev → snippet
    private(set) var maxAbbrevLength: Int = 0
    private(set) var loadedURL: URL?

    // MARK: - Load

    func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let dict = plist as? [String: Any],
                  let rawSnippets = dict["snippetsTE2"] as? [[String: Any]] else {
                print("QuickSnip: Could not find snippetsTE2 in backup file")
                return
            }

            var loaded: [Snippet] = []
            for raw in rawSnippets {
                guard let abbrev = raw["abbreviation"] as? String, !abbrev.isEmpty else { continue }
                let type = raw["snippetType"] as? Int ?? 0
                guard type == 0 || type == 1 else { continue }  // skip pictures/scripts

                let snippet = Snippet(
                    abbreviation: abbrev,
                    label: raw["label"] as? String ?? "",
                    plainText: raw["plainText"] as? String ?? "",
                    richText: raw["richText"] as? Data,
                    type: type,
                    abbreviationMode: raw["abbreviationMode"] as? Int ?? 0
                )
                loaded.append(snippet)
            }

            snippets = loaded
            loadedURL = url
            buildIndex()
            print("QuickSnip: Loaded \(snippets.count) snippets (max abbreviation length: \(maxAbbrevLength))")
        } catch {
            print("QuickSnip: Error loading backup file: \(error)")
        }
    }

    // MARK: - Mutations

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        buildIndex()
    }

    func update(_ snippet: Snippet, at index: Int) {
        guard index >= 0 && index < snippets.count else { return }
        snippets[index] = snippet
        buildIndex()
    }

    func delete(at index: Int) {
        guard index >= 0 && index < snippets.count else { return }
        snippets.remove(at: index)
        buildIndex()
    }

    // MARK: - Save

    func save() {
        guard let url = loadedURL else { return }

        // Preserve any top-level keys from the original file (version info, etc.)
        var plist: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            plist = existing
        }

        plist["snippetsTE2"] = snippets.map { s -> [String: Any] in
            var d: [String: Any] = [
                "abbreviation": s.abbreviation,
                "label": s.label,
                "plainText": s.plainText,
                "snippetType": s.type,
                "abbreviationMode": s.abbreviationMode,
            ]
            if let rt = s.richText { d["richText"] = rt }
            return d
        }

        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: url)
        }
    }

    // MARK: - Index

    private func buildIndex() {
        caseInsensitiveIndex = [:]
        caseSensitiveIndex = [:]
        maxAbbrevLength = 0

        for snippet in snippets {
            maxAbbrevLength = max(maxAbbrevLength, snippet.abbreviation.count)
            if snippet.abbreviationMode == 2 {
                caseSensitiveIndex[snippet.abbreviation] = snippet
            } else {
                caseInsensitiveIndex[snippet.abbreviation.lowercased()] = snippet
            }
        }
    }

    // MARK: - Lookup

    /// Returns the first snippet whose abbreviation matches the end of `buffer`.
    func find(in buffer: String) -> Snippet? {
        guard !buffer.isEmpty, maxAbbrevLength > 0 else { return nil }

        // Case-sensitive pass
        for (abbrev, snippet) in caseSensitiveIndex {
            if buffer.hasSuffix(abbrev) { return snippet }
        }

        // Case-insensitive pass
        let lowerBuffer = buffer.lowercased()
        for (abbrev, snippet) in caseInsensitiveIndex {
            if lowerBuffer.hasSuffix(abbrev) { return snippet }
        }

        return nil
    }
}
