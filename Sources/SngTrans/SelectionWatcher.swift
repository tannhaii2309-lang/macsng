import AppKit

/// Theo dõi chuột/phím toàn hệ thống: thấy bôi đen (kéo chuột, nhấp đúp/ba) thì lấy chữ và báo ra ngoài.
final class SelectionWatcher {
    var autoEnabled = true
    var onText: ((Selection) -> Void)?
    var onOutsideClick: (() -> Void)?
    var onEscape: (() -> Void)?

    private var monitors: [Any] = []
    private var downPoint = NSPoint.zero
    private var generation = 0

    func start() {
        stop()
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            self?.downPoint = NSEvent.mouseLocation
            self?.onOutsideClick?()      // sự kiện vào chính app không tới đây, nên luôn là bấm ra ngoài thẻ
        }) { monitors.append(m) }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] e in
            guard let self, self.autoEnabled else { return }
            let p = NSEvent.mouseLocation
            let moved = hypot(p.x - self.downPoint.x, p.y - self.downPoint.y) > 6
            guard moved || e.clickCount >= 2 else { return }
            if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               Store.shared.isBlocked(id) { return }     // app bị chặn: không tự dịch
            self.generation += 1
            let g = self.generation
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, g == self.generation, let s = SelectedText.read() else { return }
                DispatchQueue.main.async { if g == self.generation { self.onText?(s) } }
            }
        }) { monitors.append(m) }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            if e.keyCode == 53 { self?.onEscape?() }
        }) { monitors.append(m) }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }
}
