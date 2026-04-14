import AppKit

class HelpWindowController: NSWindowController {

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickSnip Help"
        window.minSize = NSSize(width: 400, height: 400)
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.textStorage?.setAttributedString(buildHelpText())

        scrollView.documentView = textView

        // Size the text view to fit
        textView.frame = NSRect(x: 0, y: 0, width: 600, height: 2000)
        textView.sizeToFit()
    }

    // MARK: - Help content

    private func buildHelpText() -> NSAttributedString {
        let result = NSMutableAttributedString()

        func heading(_ text: String) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = 20
            style.paragraphSpacing = 4
            result.append(NSAttributedString(string: "\n" + text + "\n", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ]))
        }

        func body(_ text: String) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = 6
            result.append(NSAttributedString(string: text + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ]))
        }

        func code(_ text: String) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = 4
            result.append(NSAttributedString(string: text + "\n", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: style,
            ]))
        }

        func row(_ abbrev: String, _ description: String) {
            let line = NSMutableAttributedString()
            line.append(NSAttributedString(string: "  \(abbrev)", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]))
            let padding = max(1, 16 - abbrev.count)
            line.append(NSAttributedString(string: String(repeating: " ", count: padding) + description + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]))
            result.append(line)
        }

        // ── Title ──
        result.append(NSAttributedString(string: "QuickSnip Help\n", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.labelColor,
        ]))

        // ── How it works ──
        heading("How it works")
        body("Type any abbreviation anywhere on your Mac — in Mail, Notes, a browser, anywhere — and QuickSnip instantly replaces it with the full text. No need to press Space or Return first.")
        body("Example: type  ddate  and it becomes  April 8, 2026")

        // ── Getting started ──
        heading("Getting started")
        body("1.  Click the ⚡ bolt icon in your menu bar.")
        body("2.  The menu shows your status — it should say  ✓ Active.")
        body("3.  Start typing your abbreviations!")
        body("4.  To browse or search all your snippets:  ⚡ → Manage Snippets…")
        body("5.  To load a different snippet file:  ⚡ → Load Backup File…")

        // ── Date & time codes ──
        heading("Date & Time codes  (%)")
        body("Inside any snippet's expansion text, you can use special codes that get replaced with the current date or time when the snippet fires. These start with a % sign.")
        body("")

        row("%B",  "Full month name           → April")
        row("%b",  "Short month name          → Apr")
        row("%m",  "Month number (01–12)      → 04")
        row("%e",  "Day of month (1–31)       → 8")
        row("%d",  "Day with leading zero      → 08")
        row("%Y",  "4-digit year              → 2026")
        row("%y",  "2-digit year              → 26")
        row("%A",  "Full weekday name         → Wednesday")
        row("%a",  "Short weekday name        → Wed")
        body("")
        row("%1I", "Hour, 12-hr, no zero      → 2")
        row("%I",  "Hour, 12-hr, with zero    → 02")
        row("%H",  "Hour, 24-hr               → 14")
        row("%M",  "Minutes                   → 30")
        row("%S",  "Seconds                   → 05")
        row("%p",  "AM or PM                  → PM")
        row("%P",  "am or pm (lowercase)      → pm")
        body("")

        body("Example:  %B %e, %Y  →  April 8, 2026")
        body("Example:  %1I:%M %p  →  2:30 PM")
        body("Example:  %Y-%m-%d   →  2026-04-08")

        // ── Cursor position ──
        heading("Cursor positioning  (%|)")
        body("Put  %|  anywhere in your expansion text to set where the cursor lands after expanding. Everything else gets typed, then the cursor jumps to that spot.")
        body("Example:  Dear %|,  →  types  Dear ,  then puts your cursor between Dear and the comma, ready to type a name.")

        // ── Manage Snippets window ──
        heading("Manage Snippets window")
        body("⚡ → Manage Snippets…  opens a searchable list of all your snippets.")
        body("• Search by abbreviation, label, or content.")
        body("• Double-click any row to paste that snippet wherever your cursor is (QuickSnip switches back to your previous app automatically).")

        // ── Abbreviation tips ──
        heading("Tips for writing good abbreviations")
        body("• Use a pattern that won't fire by accident. Many people double the first letter:  ddate,  ttime,  ssig.")
        body("• Or use a prefix like  ;  or  ;;  so abbreviations never clash with real words:  ;date,  ;sig.")
        body("• Keep them short enough to save keystrokes but long enough to remember.")

        // ── Loading snippet files ──
        heading("Loading your own snippets")
        body("QuickSnip reads TextExpander .textexpbackup files directly — no conversion needed.")
        body("⚡ → Load Backup File…  to switch to a different file.")
        body("Your choice is remembered between launches.")

        // ── Troubleshooting ──
        heading("Troubleshooting")
        body("⚠️ No Accessibility access  — QuickSnip needs this permission to watch keystrokes.")
        body("  Fix: System Settings → Privacy & Security → Accessibility → add QuickSnip → toggle ON → then quit and reopen QuickSnip.")
        body("")
        body("Snippets not expanding  — Check that the menu shows  ✓ Active  and  Enabled  is checked.")
        body("")
        body("Wrong app gets the paste  — Make sure you clicked in the target app before opening Manage Snippets.")

        return result
    }
}
