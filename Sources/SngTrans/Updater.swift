import AppKit

/// Kiểm tra bản mới trên GitHub Releases; có bản mới thì mở link tải .dmg.
enum Updater {
    static let repo = Links.repo

    static func check(silent: Bool) {
        Task {
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            do {
                var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=30")!)
                req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                req.timeoutInterval = 10
                let (data, _) = try await URLSession.shared.data(for: req)
                // "Latest" của repo là bản Windows, nên tìm bản Mac đầu tiên (mới nhất) có tag mac-v*
                guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let found = list.first(where: { ($0["tag_name"] as? String)?.hasPrefix("mac-v") == true
                                                      && ($0["draft"] as? Bool) != true }),
                      let raw = found["tag_name"] as? String else { throw URLError(.badServerResponse) }
                let tag = String(raw.dropFirst("mac-v".count))

                if tag.compare(current, options: .numeric) == .orderedDescending {
                    await MainActor.run {
                        let a = NSAlert()
                        a.messageText = "Có bản mới \(tag)"
                        a.informativeText = "Bạn đang dùng bản \(current). Tải bản mới về, mở file .dmg rồi kéo vào Applications để thay."
                        a.addButton(withTitle: "Tải về")
                        a.addButton(withTitle: "Để sau")
                        NSApp.activate(ignoringOtherApps: true)
                        if a.runModal() == .alertFirstButtonReturn {
                            NSWorkspace.shared.open(Links.dmg)
                        }
                    }
                } else if !silent {
                    await info("Đang dùng bản mới nhất", "SngTrans \(current)")
                }
            } catch {
                if !silent { await info("Không kiểm tra được", "Kiểm tra kết nối mạng hoặc kho phát hành chưa có bản nào.") }
            }
        }
    }

    @MainActor private static func info(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}
