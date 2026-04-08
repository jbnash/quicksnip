import AppKit
import ApplicationServices

/// Taps into the system keyboard event stream via CGEventTap.
/// Maintains a rolling buffer of recently typed characters and fires the Expander
/// the instant an abbreviation is completed.
class KeyboardMonitor {

    let store: SnippetStore
    let expander = Expander()
    var isEnabled: Bool = true
    private(set) var isRunning: Bool = false

    private var buffer: String = ""
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // C-compatible callback — cannot capture self, so we route through userInfo pointer.
    private static let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
        return monitor.handle(event: event)
    }

    init(store: SnippetStore) {
        self.store = store
    }

    // MARK: - Start / Stop

    func start() {
        // Prompt for Accessibility permission using the native system dialog.
        // If already granted this is a no-op; if not, macOS shows its own dialog.
        let options = [(kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("QuickSnip: Waiting for Accessibility permission.")
            return
        }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.tapCallback,
            userInfo: selfPtr
        ) else {
            print("QuickSnip: CGEvent.tapCreate failed even with Accessibility granted.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        print("QuickSnip: Keyboard monitor started.")
    }

    func resetBuffer() {
        buffer = ""
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    // MARK: - Event handling (runs on main thread via main run loop)

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Ignore events we generated ourselves
        if event.getIntegerValueField(.eventSourceUserData) == Expander.syntheticMarker {
            return Unmanaged.passRetained(event)
        }

        guard isEnabled else { return Unmanaged.passRetained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Any command/control/option combo → reset buffer (user is doing a shortcut)
        let hasModifier = flags.contains(.maskCommand)
                       || flags.contains(.maskControl)
                       || flags.contains(.maskAlternate)
        if hasModifier {
            buffer = ""
            return Unmanaged.passRetained(event)
        }

        switch keyCode {
        case 51:                    // Backspace/Delete — mirror in buffer
            if !buffer.isEmpty { buffer.removeLast() }
            return Unmanaged.passRetained(event)

        case 53,                    // Escape
             123, 124, 125, 126,    // Arrow keys
             36, 76,                // Return, Enter
             48,                    // Tab
             117:                   // Forward Delete
            buffer = ""
            return Unmanaged.passRetained(event)

        default:
            break
        }

        // Decode the typed Unicode character(s)
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return Unmanaged.passRetained(event) }

        let char = String(utf16CodeUnits: Array(chars.prefix(length)), count: length)

        // Only track printable characters (value ≥ 32 = space and above)
        guard let scalar = char.unicodeScalars.first, scalar.value >= 32 else {
            buffer = ""
            return Unmanaged.passRetained(event)
        }

        buffer.append(contentsOf: char)

        // Keep the buffer trimmed to the longest possible abbreviation
        let maxLen = store.maxAbbrevLength
        if maxLen > 0 && buffer.count > maxLen {
            buffer = String(buffer.suffix(maxLen))
        }

        // Check for a match
        if let snippet = store.find(in: buffer) {
            let abbrevLen = snippet.abbreviation.count
            buffer = ""
            // Let the keystroke land first, then expand on the next run-loop tick
            DispatchQueue.main.async {
                self.expander.expand(snippet, abbreviationLength: abbrevLen)
            }
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Accessibility alert

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                QuickSnip needs Accessibility access to monitor your keystrokes and expand snippets.

                Please go to System Settings › Privacy & Security › Accessibility and enable QuickSnip, then relaunch the app.
                """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
