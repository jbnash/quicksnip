import Foundation

struct Snippet {
    let abbreviation: String
    let label: String
    let plainText: String
    let richText: Data?
    let type: Int          // 0 = plain, 1 = rich text, 2 = picture (skipped)
    let abbreviationMode: Int  // 0 = case-insensitive, 2 = case-sensitive

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

    /// Returns the first snippet whose abbreviation matches the end of `buffer`.
    func find(in buffer: String) -> Snippet? {
        guard !buffer.isEmpty, maxAbbrevLength > 0 else { return nil }

        // Case-sensitive pass
        for (abbrev, snippet) in caseSensitiveIndex {
            if buffer.hasSuffix(abbrev) {
                return snippet
            }
        }

        // Case-insensitive pass (compare lowercased buffer suffix)
        let lowerBuffer = buffer.lowercased()
        for (abbrev, snippet) in caseInsensitiveIndex {
            if lowerBuffer.hasSuffix(abbrev) {
                return snippet
            }
        }

        return nil
    }
}
