import AppKit
import ApplicationServices

/// Lấy chữ đang bôi đen: ưu tiên Accessibility API; app nào không hỗ trợ (Chrome, Electron...)
/// thì gửi ⌘C rồi trả clipboard về như cũ.
enum SelectedText {
    static let maxChars = 1500
    private static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty", "com.mitchellh.ghostty", "org.alacritty",
    ]

    /// Gọi trên luồng nền.
    static func read() -> String? {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == Bundle.main.bundleIdentifier { return nil }
        if let t = viaAccessibility() { return clean(t) }
        // ⌘C trong terminal là ngắt chương trình, nên bỏ qua
        if let id = front?.bundleIdentifier, terminals.contains(id) { return nil }
        return viaCopy().flatMap(clean)
    }

    private static func clean(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return t.count > maxChars ? String(t.prefix(maxChars)) : t
    }

    private static func viaAccessibility() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let sys = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let f = focused else { return nil }
        var sel: CFTypeRef?
        guard AXUIElementCopyAttributeValue(f as! AXUIElement, kAXSelectedTextAttribute as CFString, &sel) == .success,
              let s = sel as? String, !s.isEmpty else { return nil }
        return s
    }

    private static func viaCopy() -> String? {
        guard AXIsProcessTrusted() else { return nil }   // gửi phím cũng cần quyền Trợ năng
        let pb = NSPasteboard.general
        let saved: [[(NSPasteboard.PasteboardType, Data)]] = (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }
        let before = pb.changeCount
        Thread.sleep(forTimeInterval: 0.08)
        sendCmdC()
        var text: String?
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.03)
            if pb.changeCount != before { text = pb.string(forType: .string); break }
        }
        if pb.changeCount != before {
            pb.clearContents()
            for item in saved {
                let n = NSPasteboardItem()
                for (t, d) in item { n.setData(d, forType: t) }
                pb.writeObjects([n])
            }
        }
        return text
    }

    private static func sendCmdC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: down)   // 8 = phím C
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
    }
}
