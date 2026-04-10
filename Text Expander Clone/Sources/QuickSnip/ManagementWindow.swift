import AppKit

// MARK: - ManagementWindowController

class ManagementWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    private let store: SnippetStore
    private weak var appDelegate: AppDelegate?
    private let expander = Expander()

    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var countLabel: NSTextField!
    private var filteredSnippets: [Snippet] = []

    // Bottom toolbar
    private var editButton: NSButton!
    private var deleteButton: NSButton!
    private var pasteButton: NSButton!

    // Held so ARC doesn't drop it before the sheet dismisses
    private var activeSheet: SnippetEditSheet?

    init(store: SnippetStore, appDelegate: AppDelegate) {
        self.store = store
        self.appDelegate = appDelegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickSnip — Snippets"
        window.minSize = NSSize(width: 500, height: 340)
        window.center()

        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - UI setup

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // --- Search field ---
        searchField = NSSearchField()
        searchField.placeholderString = "Search abbreviations, labels, or content…"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchChanged)
        contentView.addSubview(searchField)

        // --- Count label ---
        countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)

        // --- Scroll view + table ---
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 34
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.doubleAction = #selector(rowDoubleClicked)

        for col in [
            makeColumn(id: "abbrev",  title: "Abbreviation", width: 130, minWidth: 80),
            makeColumn(id: "type",    title: "Type",         width: 50,  minWidth: 40),
            makeColumn(id: "label",   title: "Label",        width: 160, minWidth: 80),
            makeColumn(id: "preview", title: "Expansion",    width: 340, minWidth: 120),
        ] { tableView.addTableColumn(col) }

        scrollView.documentView = tableView

        // --- Separator ---
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

        // --- Bottom toolbar ---
        let addButton = makeButton(title: "+ New",  action: #selector(addSnippet))
        deleteButton  = makeButton(title: "Delete", action: #selector(deleteSnippet))
        editButton    = makeButton(title: "Edit…",  action: #selector(editSnippet))
        pasteButton   = makeButton(title: "⌘ Paste", action: #selector(pasteSnippet))

        deleteButton.isEnabled = false
        editButton.isEnabled   = false
        pasteButton.isEnabled  = false

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = NSTextField(labelWithString: "Double-click to edit  ·  Select then Paste to insert at cursor")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = NSStackView(views: [addButton, deleteButton, hintLabel, spacer, editButton, pasteButton])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomBar)

        // --- Layout ---
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -120),

            countLabel.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 1),
        ])

        reload()
    }

    private func makeColumn(id: String, title: String, width: CGFloat, minWidth: CGFloat) -> NSTableColumn {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        col.title = title
        col.width = width
        col.minWidth = minWidth
        return col
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    // MARK: - Data

    func reload() {
        applyFilter(searchField?.stringValue ?? "")
        updateButtonState()
    }

    @objc private func searchChanged() {
        applyFilter(searchField.stringValue)
    }

    private func applyFilter(_ query: String) {
        if query.isEmpty {
            filteredSnippets = store.snippets
        } else {
            let q = query.lowercased()
            filteredSnippets = store.snippets.filter {
                $0.abbreviation.lowercased().contains(q)
                || $0.label.lowercased().contains(q)
                || $0.plainText.lowercased().contains(q)
            }
        }
        countLabel?.stringValue = "\(filteredSnippets.count) of \(store.snippets.count) snippets"
        tableView?.reloadData()
    }

    private func updateButtonState() {
        let has = tableView.selectedRow >= 0
        editButton.isEnabled   = has
        deleteButton.isEnabled = has
        pasteButton.isEnabled  = has
    }

    // MARK: - Row actions

    @objc private func rowClicked() {
        updateButtonState()
    }

    @objc private func rowDoubleClicked() {
        editSnippet()
    }

    // MARK: - Toolbar actions

    @objc private func addSnippet() {
        openSheet(snippet: Snippet(abbreviation: "", label: "", plainText: "", richText: nil,
                                   type: 0, abbreviationMode: 0), storeIndex: nil)
    }

    @objc private func editSnippet() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredSnippets.count else { return }
        let snippet = filteredSnippets[row]
        let storeIndex = storeIndexFor(filteredRow: row)
        openSheet(snippet: snippet, storeIndex: storeIndex)
    }

    @objc private func deleteSnippet() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredSnippets.count else { return }
        let snippet = filteredSnippets[row]
        guard let window = window else { return }

        let alert = NSAlert()
        alert.messageText = "Delete \"\(snippet.abbreviation)\"?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .alertFirstButtonReturn else { return }
            if let idx = self.storeIndexFor(filteredRow: row) {
                self.store.delete(at: idx)
                self.store.save()
                self.reload()
            }
        }
    }

    @objc private func pasteSnippet() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredSnippets.count else { return }
        let snippet = filteredSnippets[row]
        let targetApp = appDelegate?.lastFrontApp
        window?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            targetApp?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.expander.expand(snippet, abbreviationLength: 0)
            }
        }
    }

    // MARK: - Edit sheet

    private func openSheet(snippet: Snippet, storeIndex: Int?) {
        guard let window = window else { return }
        let sheet = SnippetEditSheet(snippet: snippet, isNew: storeIndex == nil)
        activeSheet = sheet
        sheet.onSave = { [weak self] updated in
            guard let self = self else { return }
            if let idx = storeIndex {
                self.store.update(updated, at: idx)
            } else {
                self.store.add(updated)
            }
            self.store.save()
            self.reload()
            self.activeSheet = nil
        }
        sheet.onCancel = { [weak self] in self?.activeSheet = nil }
        sheet.beginSheet(in: window)
    }

    // MARK: - Helpers

    /// Finds the store index for a row in the current filtered list.
    private func storeIndexFor(filteredRow: Int) -> Int? {
        guard filteredRow >= 0, filteredRow < filteredSnippets.count else { return nil }
        let snippet = filteredSnippets[filteredRow]
        return store.snippets.firstIndex {
            $0.abbreviation == snippet.abbreviation && $0.label == snippet.label
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { filteredSnippets.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let snippet = filteredSnippets[row]
        let colID = tableColumn?.identifier.rawValue ?? ""
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingTail
        cell.usesSingleLineMode = true

        switch colID {
        case "abbrev":
            cell.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            cell.stringValue = snippet.abbreviation
        case "type":
            cell.font = NSFont.systemFont(ofSize: 11)
            cell.textColor = .tertiaryLabelColor
            cell.stringValue = snippet.type == 1 ? "RTF" : "TXT"
            cell.alignment = .center
        case "label":
            cell.font = NSFont.systemFont(ofSize: 12)
            cell.textColor = .secondaryLabelColor
            cell.stringValue = snippet.label
        case "preview":
            cell.font = NSFont.systemFont(ofSize: 12)
            cell.textColor = .secondaryLabelColor
            cell.stringValue = String(snippet.displayPreview.prefix(140))
        default: break
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }
}

// MARK: - SnippetEditSheet

/// A self-contained sheet that edits or creates a snippet.
class SnippetEditSheet: NSObject {

    var onSave:   ((Snippet) -> Void)?
    var onCancel: (() -> Void)?

    private var snippet: Snippet
    private let isNew: Bool
    private var panel: NSPanel!
    private var abbrevField: NSTextField!
    private var labelField:  NSTextField!
    private var textView:    NSTextView!

    init(snippet: Snippet, isNew: Bool) {
        self.snippet = snippet
        self.isNew   = isNew
        super.init()
        buildPanel()
    }

    func beginSheet(in window: NSWindow) {
        window.beginSheet(panel) { [weak self] response in
            guard let self = self else { return }
            if response == .OK {
                var updated = self.snippet
                updated.abbreviation = self.abbrevField.stringValue.trimmingCharacters(in: .whitespaces)
                updated.label        = self.labelField.stringValue.trimmingCharacters(in: .whitespaces)
                updated.plainText    = self.textView.string
                guard !updated.abbreviation.isEmpty else { return }
                self.onSave?(updated)
            } else {
                self.onCancel?()
            }
        }
    }

    // MARK: - Build panel

    private func buildPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = isNew ? "New Snippet" : "Edit Snippet"
        let cv = panel.contentView!

        // Labels
        let abbrevLabel = label("Abbreviation:")
        let labelLabel  = label("Label:")
        let expLabel    = label("Expansion:")

        // Fields
        abbrevField = NSTextField()
        abbrevField.stringValue       = snippet.abbreviation
        abbrevField.placeholderString = "e.g.  ddate"
        abbrevField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        abbrevField.translatesAutoresizingMaskIntoConstraints = false

        labelField = NSTextField()
        labelField.stringValue       = snippet.label
        labelField.placeholderString = "e.g.  Today's date  (optional)"
        labelField.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView = NSTextView()
        textView.string = snippet.plainText
        textView.font   = NSFont.systemFont(ofSize: 13)
        textView.isRichText  = false
        textView.isEditable  = true
        textView.allowsUndo  = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        scrollView.documentView = textView

        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle    = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.bezelStyle    = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        cv.addSubview(abbrevLabel)
        cv.addSubview(labelLabel)
        cv.addSubview(expLabel)
        cv.addSubview(abbrevField)
        cv.addSubview(labelField)
        cv.addSubview(scrollView)
        cv.addSubview(cancelButton)
        cv.addSubview(saveButton)

        let colW: CGFloat = 100
        NSLayoutConstraint.activate([
            abbrevLabel.topAnchor.constraint(equalTo: cv.topAnchor, constant: 24),
            abbrevLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            abbrevLabel.widthAnchor.constraint(equalToConstant: colW),

            abbrevField.centerYAnchor.constraint(equalTo: abbrevLabel.centerYAnchor),
            abbrevField.leadingAnchor.constraint(equalTo: abbrevLabel.trailingAnchor, constant: 8),
            abbrevField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),

            labelLabel.topAnchor.constraint(equalTo: abbrevLabel.bottomAnchor, constant: 14),
            labelLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            labelLabel.widthAnchor.constraint(equalToConstant: colW),

            labelField.centerYAnchor.constraint(equalTo: labelLabel.centerYAnchor),
            labelField.leadingAnchor.constraint(equalTo: labelLabel.trailingAnchor, constant: 8),
            labelField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),

            expLabel.topAnchor.constraint(equalTo: labelLabel.bottomAnchor, constant: 14),
            expLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: expLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -16),

            cancelButton.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),

            saveButton.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
            saveButton.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.systemFont(ofSize: 13)
        f.alignment = .right
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    @objc private func save()   { NSApp.endSheet(panel, returnCode: NSApplication.ModalResponse.OK.rawValue)     }
    @objc private func cancel() { NSApp.endSheet(panel, returnCode: NSApplication.ModalResponse.cancel.rawValue) }
}
