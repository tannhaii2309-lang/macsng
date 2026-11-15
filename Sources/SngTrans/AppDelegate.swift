import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let langs: [(code: String, name: String)] = [
        ("vi", "Tiếng Việt"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"),
        ("zh-CN", "中文 (简体)"), ("fr", "Français"), ("de", "Deutsch"),
        ("es", "Español"), ("ru", "Русский"), ("th", "ไทย"),
    ]

    private var statusItem: NSStatusItem!
    private var card: CardController!
    private let watcher = SelectionWatcher()
    private var hk1: HotKey?, hk2: HotKey?
    private var wasTrusted = false
    private let defaults = UserDefaults.standard

    private var targetLang: String { defaults.string(forKey: "tl") ?? "vi" }
    private var auto: Bool {
        get { defaults.object(forKey: "auto") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "auto") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        card = CardController(targetLang: { [unowned self] in self.targetLang })
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        refreshUI()

        // Hỏi quyền Trợ năng (bắt buộc để đọc chữ bôi đen)
        wasTrusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        watcher.autoEnabled = auto
        watcher.onText = { [weak self] t in self?.card.show(text: t) }
        watcher.onOutsideClick = { [weak self] in self?.card.hideIfNotPinned() }
        watcher.onEscape = { [weak self] in self?.card.hideIfNotPinned() }
        watcher.start()

        // ⌥1 dịch ngay phần đang chọn, ⌥2 bật/tắt tự dịch
        hk1 = HotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(optionKey)) { [weak self] in self?.translateNow() }
        hk2 = HotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(optionKey)) { [weak self] in self?.toggleAuto() }

        // Người dùng cấp quyền xong thì tự nạp lại bộ theo dõi, không cần mở lại app
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = AXIsProcessTrusted()
            if now && !self.wasTrusted { self.watcher.start() }
            self.wasTrusted = now
        }
    }

    // MARK: - Menu

    private func refreshUI() {
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: auto ? "character.bubble.fill" : "character.bubble",
                              accessibilityDescription: "SngTrans")
            b.toolTip = auto ? "SngTrans: đang tự dịch khi bôi đen" : "SngTrans: tự dịch đang tắt"
        }
        let menu = NSMenu()
        menu.addItem(item("Dịch phần đang chọn", #selector(translateNowAction), key: "1"))
        let a = item("Tự dịch khi bôi đen", #selector(toggleAutoAction), key: "2")
        a.state = auto ? .on : .off
        menu.addItem(a)
        menu.addItem(.separator())

        let langMenu = NSMenu()
        for l in Self.langs {
            let i = NSMenuItem(title: l.name, action: #selector(pickLang(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = l.code
            i.state = l.code == targetLang ? .on : .off
            langMenu.addItem(i)
        }
        let langItem = NSMenuItem(title: "Dịch sang", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)
        menu.addItem(.separator())

        let login = item("Chạy cùng macOS", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Cấp quyền Trợ năng…", #selector(openAccessibility)))
        menu.addItem(.separator())
        menu.addItem(item("Thoát", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        if key == "1" || key == "2" { i.keyEquivalentModifierMask = [.option] }
        return i
    }

    // MARK: - Hành động

    private func translateNow() {
        DispatchQueue.global().async { [weak self] in
            guard let t = SelectedText.read() else { return }
            DispatchQueue.main.async { self?.card.show(text: t) }
        }
    }

    private func toggleAuto() {
        auto.toggle()
        watcher.autoEnabled = auto
        refreshUI()
    }

    @objc private func translateNowAction() { translateNow() }
    @objc private func toggleAutoAction() { toggleAuto() }

    @objc private func pickLang(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String { defaults.set(code, forKey: "tl") }
        refreshUI()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { NSSound.beep() }
        refreshUI()
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
