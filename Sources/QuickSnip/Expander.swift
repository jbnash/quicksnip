import AppKit

/// Handles the actual text expansion: deletes the typed abbreviation, then pastes the expansion.
/// Uses the clipboard for both plain and rich text so all apps get the right content instantly.
class Expander {

    /// A magic number stamped on synthetic CGEvents so KeyboardMonitor ignores them.
    static let syntheticMarker: Int64 = 0x514B534E4950  // "QKSNIP" in hex

    // MARK: - Public entry point

    func expand(_ snippet: Snippet, abbreviationLength: Int) {
        // 1. Delete the abbreviation characters the user just typed
        deleteCharacters(count: abbreviationLength)

        // 2. Paste the expansion (plain or rich)
        if snippet.type == 1, let rtfData = snippet.richText {
            pasteRichText(rtfData, plainFallback: snippet.plainText)
        } else {
            pasteText(snippet.plainText)
        }
    }

    // MARK: - Delete

    private func deleteCharacters(count: Int) {
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            // Virtual key 0x33 = Delete/Backspace
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
            mark(down); mark(up)
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    // MARK: - Plain text paste

    private func pasteText(_ text: String) {
        let processed = DateMacros.process(text)
        let (finalText, cursorOffset) = extractCursorPosition(processed)

        let saved = saveClipboard()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(finalText, forType: .string)

        sendCmdV()

        if cursorOffset > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                self.sendLeftArrows(count: cursorOffset)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.restoreClipboard(saved)
        }
    }

    // MARK: - Rich text paste

    private func pasteRichText(_ data: Data, plainFallback: String) {
        // The richText field uses the old NSStreamTyped binary archive format.
        // NSUnarchiver (deprecated but functional) is the only way to decode it.
        if let attrStr = decodeStreamTyped(data) {
            pasteAttributedString(attrStr, fallback: plainFallback)
        } else {
            // Fall back to plain text if decoding fails
            pasteText(plainFallback)
        }
    }

    private func decodeStreamTyped(_ data: Data) -> NSAttributedString? {
        // NSUnarchiver handles the old streamtyped format from TextExpander
        guard data.count > 12 else { return nil }
        return NSUnarchiver.unarchiveObject(with: data) as? NSAttributedString
    }

    private func pasteAttributedString(_ attrStr: NSAttributedString, fallback: String) {
        let range = NSRange(location: 0, length: attrStr.length)
        let saved = saveClipboard()
        let pb = NSPasteboard.general
        pb.clearContents()

        // Write richest format first, then fall-through formats
        if let rtfd = attrStr.rtfd(from: range, documentAttributes: [:]) {
            pb.setData(rtfd, forType: .rtfd)
        }
        if let rtf = attrStr.rtf(from: range, documentAttributes: [:]) {
            pb.setData(rtf, forType: .rtf)
        }
        pb.setString(attrStr.string, forType: .string)

        sendCmdV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.restoreClipboard(saved)
        }
    }

    // MARK: - Cursor positioning

    /// Extracts `%|` from the text and returns (cleanedText, charsAfterCursor).
    private func extractCursorPosition(_ text: String) -> (String, Int) {
        guard let range = text.range(of: "%|") else { return (text, 0) }
        let charsAfter = text.distance(from: range.upperBound, to: text.endIndex)
        return (text.replacingOccurrences(of: "%|", with: ""), charsAfter)
    }

    // MARK: - Synthetic key events

    private func sendCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        // Virtual key 0x09 = V
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        mark(down); mark(up)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func sendLeftArrows(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            // Virtual key 0x7B = left arrow
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: true)
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0x7B, keyDown: false)
            mark(down); mark(up)
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    private func mark(_ event: CGEvent?) {
        event?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
    }

    // MARK: - Clipboard save / restore

    typealias ClipboardContents = [(NSPasteboard.PasteboardType, Data)]

    private func saveClipboard() -> ClipboardContents {
        let pb = NSPasteboard.general
        var saved: ClipboardContents = []
        for type in pb.types ?? [] {
            if let data = pb.data(forType: type) {
                saved.append((type, data))
            }
        }
        return saved
    }

    private func restoreClipboard(_ saved: ClipboardContents) {
        let pb = NSPasteboard.general
        pb.clearContents()
        for (type, data) in saved {
            pb.setData(data, forType: type)
        }
    }
}
