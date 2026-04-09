import Foundation

struct Snippet: Codable {
    var id: UUID
    var abbreviation: String
    var label: String
    var plainText: String
    let richText: Data?
    var type: Int               // 0 = plain, 1 = rich text, 2 = picture (skipped)
    var abbreviationMode: Int   // 0 = case-insensitive, 2 = case-sensitive

    init(id: UUID = UUID(), abbreviation: String, label: String = "",
         plainText: String, richText: Data? = nil, type: Int = 0, abbreviationMode: Int = 0) {
        self.id = id
        self.abbreviation = abbreviation
        self.label = label
        self.plainText = plainText
        self.richText = richText
        self.type = type
        self.abbreviationMode = abbreviationMode
    }

    var displayPreview: String {
        plainText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

class SnippetStore {
    private(set) var snippets: [Snippet] = []
    private var caseInsensitiveIndex: [String: Snippet] = [:]
    private var caseSensitiveIndex:   [String: Snippet] = [:]
    private(set) var maxAbbrevLength: Int = 0
    private(set) var loadedURL: URL?

    private static let saveKey = "savedSnippets"

    init() {
        loadSaved()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    private func loadSaved() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let saved = try? JSONDecoder().decode([Snippet].self, from: data) else { return }
        snippets = saved
        buildIndex()
        print("QuickSnip: Loaded \(snippets.count) saved snippets")
    }

    // MARK: - Load from backup file

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
                guard type == 0 || type == 1 else { continue }

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
            save()
            print("QuickSnip: Loaded \(snippets.count) snippets from backup (max abbreviation length: \(maxAbbrevLength))")
        } catch {
            print("QuickSnip: Error loading backup file: \(error)")
        }
    }

    // MARK: - CRUD

    func addSnippet(abbreviation: String, label: String, text: String) {
        let snippet = Snippet(abbreviation: abbreviation, label: label, plainText: text)
        snippets.insert(snippet, at: 0)
        buildIndex()
        save()
    }

    func updateSnippet(id: UUID, abbreviation: String, label: String, text: String) {
        guard let idx = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[idx].abbreviation = abbreviation
        snippets[idx].label = label
        snippets[idx].plainText = text
        buildIndex()
        save()
    }

    func deleteSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        buildIndex()
        save()
    }

    // MARK: - Index

    private func buildIndex() {
        caseInsensitiveIndex = [:]
        caseSensitiveIndex   = [:]
        maxAbbrevLength      = 0

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
