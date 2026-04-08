import AppKit

// No dock icon — QuickSnip lives exclusively in the menu bar
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
