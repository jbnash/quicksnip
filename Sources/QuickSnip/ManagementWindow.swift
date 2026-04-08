import AppKit

/// A simple snippet browser: searchable list showing abbreviation, label, and expansion preview.
/// Double-clicking a row pastes that snippet wherever the user's cursor was.
class ManagementWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    private let store: SnippetStore
    private weak var appDelegate: AppDelegate?
    private let expander = Expander()

    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var countLabel: NSTextField!
    private var hintLabel: NSTextField!
    private var filteredSnippets: [Snippet] = []

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

        // --- Count + hint labels ---
        countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)

        hintLabel = NSTextField(labelWithString: "Double-click a snippet to paste it at your cursor")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)

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
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
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
    }

    // MARK: - Double-click to expand

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < filteredSnippets.count else { return }
        let snippet = filteredSnippets[row]

        // Grab the app the user was in before opening this window
        let targetApp = appDelegate?.lastFrontApp

        // Close this window so it doesn't interfere with focus
        window?.orderOut(nil)

        // Give the target app time to regain focus, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            targetApp?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                // Expand with 0 deletions — we're injecting fresh, not replacing an abbreviation
                self.expander.expand(snippet, abbreviationLength: 0)
            }
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

        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }
}
