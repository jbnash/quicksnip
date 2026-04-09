import AppKit

class ManagementWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    private let store: SnippetStore
    private weak var appDelegate: AppDelegate?
    private let expander = Expander()

    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var countLabel: NSTextField!
    private var hintLabel: NSTextField!
    private var filteredSnippets: [Snippet] = []

    private var editButton: NSButton!
    private var deleteButton: NSButton!

    // Held during an active edit sheet
    private var activeAbbrevField: NSTextField?
    private var activeLabelField: NSTextField?
    private var activeTextView: NSTextView?
    private var activeEditingSnippet: Snippet?  // nil = new snippet

    init(store: SnippetStore, appDelegate: AppDelegate) {
        self.store = store
        self.appDelegate = appDelegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickSnip — Snippets"
        window.minSize = NSSize(width: 500, height: 300)
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

        // --- Hint + count labels ---
        hintLabel = NSTextField(labelWithString: "Double-click a snippet to paste it at your cursor")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)

        countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)

        // --- Bottom button bar ---
        let buttonBar = NSView()
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonBar)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.addSubview(separator)

        let addButton = NSButton(title: "+", target: self, action: #selector(addSnippetTapped))
        addButton.bezelStyle = .regularSquare
        addButton.font = NSFont.systemFont(ofSize: 16, weight: .light)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.toolTip = "Add new snippet"
        buttonBar.addSubview(addButton)

        deleteButton = NSButton(title: "−", target: self, action: #selector(deleteSnippetTapped))
        deleteButton.bezelStyle = .regularSquare
        deleteButton.font = NSFont.systemFont(ofSize: 16, weight: .light)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isEnabled = false
        deleteButton.toolTip = "Delete selected snippet"
        buttonBar.addSubview(deleteButton)

        editButton = NSButton(title: "Edit", target: self, action: #selector(editSnippetTapped))
        editButton.bezelStyle = .rounded
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.isEnabled = false
        editButton.toolTip = "Edit selected snippet"
        buttonBar.addSubview(editButton)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: buttonBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: buttonBar.trailingAnchor),

            addButton.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor, constant: 8),
            addButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor, constant: 2),
            addButton.widthAnchor.constraint(equalToConstant: 24),
            addButton.heightAnchor.constraint(equalToConstant: 24),

            deleteButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 2),
            deleteButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor, constant: 2),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),

            editButton.trailingAnchor.constraint(equalTo: buttonBar.trailingAnchor, constant: -12),
            editButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor, constant: 2),
        ])

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
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.target = self

        for col in [
            makeColumn(id: "abbrev",  title: "Abbreviation", width: 130, minWidth: 80),
            makeColumn(id: "type",    title: "Type",         width: 50,  minWidth: 40),
            makeColumn(id: "label",   title: "Label",        width: 160, minWidth: 80),
            makeColumn(id: "preview", title: "Expansion",    width: 340, minWidth: 120),
        ] { tableView.addTableColumn(col) }

        scrollView.documentView = tableView

        // --- Layout ---
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            hintLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 5),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),

            countLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 5),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),

            buttonBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            buttonBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            buttonBar.heightAnchor.constraint(equalToConstant: 36),
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

    // MARK: - Data

    func reload() {
        applyFilter(searchField?.stringValue ?? "")
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
        updateButtonStates()
    }

    private func updateButtonStates() {
        let hasSelection = tableView != nil && tableView.selectedRow >= 0
        editButton?.isEnabled = hasSelection
        deleteButton?.isEnabled = hasSelection
    }

    // MARK: - Table selection

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }

    // MARK: - Double-click to paste

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
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

    // MARK: - CRUD actions

    @objc private func addSnippetTapped() {
        showEditSheet(snippet: nil)
    }

    @objc private func editSnippetTapped() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredSnippets.count else { return }
        showEditSheet(snippet: filteredSnippets[row])
    }

    @objc private func deleteSnippetTapped() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredSnippets.count else { return }
        let snippet = filteredSnippets[row]

        let alert = NSAlert()
        alert.messageText = "Delete \"\(snippet.abbreviation)\"?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.buttons.first?.hasDestructiveAction = true

        guard let mainWindow = window else { return }
        alert.beginSheetModal(for: mainWindow) { response in
            if response == .alertFirstButtonReturn {
                self.store.deleteSnippet(id: snippet.id)
                self.reload()
            }
        }
    }

    // MARK: - Edit sheet

    private func showEditSheet(snippet: Snippet?) {
        guard let mainWindow = window else { return }
        activeEditingSnippet = snippet
        let isNew = snippet == nil

        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 295),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheetWindow.title = isNew ? "New Snippet" : "Edit Snippet"

        let content = sheetWindow.contentView!

        func sectionLabel(_ text: String) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            l.textColor = .secondaryLabelColor
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }

        func inputField(placeholder: String, mono: Bool = false) -> NSTextField {
            let f = NSTextField()
            f.placeholderString = placeholder
            f.font = mono
                ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                : NSFont.systemFont(ofSize: 13)
            f.translatesAutoresizingMaskIntoConstraints = false
            return f
        }

        let abbrevLabel = sectionLabel("ABBREVIATION")
        let labelLabel  = sectionLabel("LABEL")
        let textLabel   = sectionLabel("EXPANSION")

        let abbrevField = inputField(placeholder: "e.g. tthanks", mono: true)
        let labelField  = inputField(placeholder: "e.g. Thank you")

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isRichText = false
        textView.isEditable = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        // Pre-fill from existing snippet
        abbrevField.stringValue = snippet?.abbreviation ?? ""
        labelField.stringValue  = snippet?.label ?? ""
        textView.string         = snippet?.plainText ?? ""

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(dismissSheet(_:)))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let saveBtn = NSButton(title: isNew ? "Add" : "Save", target: self, action: #selector(dismissSheet(_:)))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.translatesAutoresizingMaskIntoConstraints = false

        for v in [abbrevLabel, labelLabel, textLabel, abbrevField, labelField,
                  scrollView, cancelBtn, saveBtn] as [NSView] {
            content.addSubview(v)
        }

        NSLayoutConstraint.activate([
            abbrevLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            abbrevLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            abbrevField.topAnchor.constraint(equalTo: abbrevLabel.bottomAnchor, constant: 4),
            abbrevField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            abbrevField.widthAnchor.constraint(equalToConstant: 160),

            labelLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            labelLabel.leadingAnchor.constraint(equalTo: abbrevField.trailingAnchor, constant: 16),

            labelField.topAnchor.constraint(equalTo: labelLabel.bottomAnchor, constant: 4),
            labelField.leadingAnchor.constraint(equalTo: abbrevField.trailingAnchor, constant: 16),
            labelField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            textLabel.topAnchor.constraint(equalTo: abbrevField.bottomAnchor, constant: 16),
            textLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 120),

            cancelBtn.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -8),
            cancelBtn.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),

            saveBtn.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            saveBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            saveBtn.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),
        ])

        activeAbbrevField = abbrevField
        activeLabelField  = labelField
        activeTextView    = textView

        mainWindow.beginSheet(sheetWindow) { [weak self] response in
            guard let self = self, response == .OK else {
                self?.clearActiveSheet()
                return
            }

            let abbrev = self.activeAbbrevField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
            let lbl    = self.activeLabelField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
            let text   = self.activeTextView?.string ?? ""

            guard !abbrev.isEmpty else {
                self.clearActiveSheet()
                return
            }

            if let existing = self.activeEditingSnippet {
                self.store.updateSnippet(id: existing.id, abbreviation: abbrev, label: lbl, text: text)
            } else {
                self.store.addSnippet(abbreviation: abbrev, label: lbl, text: text)
            }

            self.clearActiveSheet()
            self.reload()
        }
    }

    @objc private func dismissSheet(_ sender: NSButton) {
        guard let sheetWindow = sender.window else { return }
        let isSave = sender.title == "Save" || sender.title == "Add"
        window?.endSheet(sheetWindow, returnCode: isSave ? .OK : .cancel)
    }

    private func clearActiveSheet() {
        activeAbbrevField    = nil
        activeLabelField     = nil
        activeTextView       = nil
        activeEditingSnippet = nil
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

        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }
}
