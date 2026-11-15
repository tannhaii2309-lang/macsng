import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // chỉ nằm ở thanh menu, không hiện ở Dock
app.run()
