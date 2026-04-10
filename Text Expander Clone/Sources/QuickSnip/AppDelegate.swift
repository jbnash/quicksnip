import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var enableMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private let store = SnippetStore()
    private var monitor: KeyboardMonitor?
    private var managementController: ManagementWindowController?
    private var helpController: HelpWindowController?
    private var feedbackController: FeedbackWindowController?

    // Last non-QuickSnip app the user was in — used for double-click-to-expand
    private(set) var lastFrontApp: NSRunningApplication?

    // MARK: - Launch

    // If the menu bar icon is hidden (e.g. behind the notch), the user can
    // re-open the app from Finder/Applications to get to the management window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showManagement()
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenuBar()
        loadSavedBackupOrPrompt()
        startMonitor()

        // Track app switches so double-click-to-expand knows where to paste
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appSwitched(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    // MARK: - Menu bar

    private func buildMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // SF Symbol — bolt = "fast expansion"; renders as a crisp monochrome template icon
            let image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "QuickSnip")
            image?.isTemplate = true  // lets macOS auto-invert for dark/light menu bar
            button.image = image
            button.toolTip = "QuickSnip"
        }

        let menu = NSMenu()

        let header = NSMenuItem(title: "QuickSnip", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        statusMenuItem = NSMenuItem(title: "● Checking…", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        menu.addItem(statusMenuItem!)

        menu.addItem(.separator())

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.state = .on
        enableMenuItem = enableItem
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem(title: "Restart Monitoring", action: #selector(restartMonitoring), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Manage Snippets…", action: #selector(showManagement), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Load Backup File…",  action: #selector(loadBackupFile),  keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Help…",             action: #selector(showHelp),         keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Give Feedback…",   action: #selector(giveFeedback),      keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickSnip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Refresh status after a tick (gives the tap time to start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.refreshStatus() }
    }

    // MARK: - Snippet loading

    private func loadSavedBackupOrPrompt() {
        // Returning user — load their saved file
        if let path = UserDefaults.standard.string(forKey: "backupFilePath"),
           FileManager.default.fileExists(atPath: path) {
            store.load(from: URL(fileURLWithPath: path))
            refreshStatus()
            return
        }
        // First launch — auto-load the starter snippets bundled inside the app
        if let url = Bundle.main.url(forResource: "StarterSnippets", withExtension: "textexpbackup") {
            store.load(from: url)
            refreshStatus()
            return
        }
        // Fallback: prompt the user to pick a file
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.loadBackupFile() }
    }

    @objc private func loadBackupFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Your TextExpander Backup File"
        panel.message = "Choose a .textexpbackup file to load your snippets."
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        store.load(from: url)
        UserDefaults.standard.set(url.path, forKey: "backupFilePath")
        refreshStatus()
        managementController?.reload()
    }

    // MARK: - Monitor

    private func startMonitor() {
        monitor = KeyboardMonitor(store: store)
        monitor?.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refreshStatus() }
    }

    @objc private func restartMonitoring() {
        monitor?.stop()
        monitor?.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refreshStatus() }
    }

    @objc private func appSwitched(_ note: Notification) {
        if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastFrontApp = app
        }
        monitor?.resetBuffer()
    }

    // MARK: - UI actions

    @objc private func toggleEnabled() {
        guard let monitor = monitor else { return }
        monitor.isEnabled.toggle()
        enableMenuItem?.state = monitor.isEnabled ? .on : .off
        refreshStatus()
    }

    @objc private func giveFeedback() {
        if feedbackController == nil { feedbackController = FeedbackWindowController() }
        feedbackController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showHelp() {
        if helpController == nil { helpController = HelpWindowController() }
        helpController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showManagement() {
        if managementController == nil {
            managementController = ManagementWindowController(store: store, appDelegate: self)
        }
        managementController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Status refresh

    func refreshStatus() {
        let hasAccess = AXIsProcessTrusted()
        let isRunning = monitor?.isRunning ?? false
        let enabled   = monitor?.isEnabled ?? true
        let count     = store.snippets.count

        if !hasAccess {
            statusMenuItem?.title = "⚠️ No Accessibility access"
            statusMenuItem?.action = #selector(openAccessibilitySettings)
            statusMenuItem?.target = self
            statusMenuItem?.isEnabled = true
        } else if !isRunning {
            statusMenuItem?.title = "⚠️ Monitoring not started"
            statusMenuItem?.isEnabled = false
        } else if !enabled {
            statusMenuItem?.title = "⏸ Disabled — \(count) snippets"
            statusMenuItem?.isEnabled = false
        } else {
            statusMenuItem?.title = "✓ Active — \(count) snippets"
            statusMenuItem?.isEnabled = false
        }
    }

    @objc private func openAccessibilitySettings() {
        // Re-trigger the native system permission prompt, then restart monitoring
        monitor?.stop()
        monitor?.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refreshStatus() }
    }
}
