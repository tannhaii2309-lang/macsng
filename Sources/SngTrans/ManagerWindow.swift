import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ManagerView: View {
    @ObservedObject var store = Store.shared

    var body: some View {
        TabView {
            notesTab.tabItem { Label("Ghi chú", systemImage: "bookmark") }
            blockedTab.tabItem { Label("Chặn app", systemImage: "nosign") }
        }
        .frame(minWidth: 560, minHeight: 380)
        .padding(8)
    }

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(store.notes.count) ghi chú").foregroundStyle(.secondary)
                Spacer()
                Button("Xuất CSV…", action: exportCSV).disabled(store.notes.isEmpty)
            }
            if store.notes.isEmpty {
                Spacer()
                Text("Chưa có ghi chú. Bấm biểu tượng dấu trang trên thẻ dịch để lưu.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(store.notes) { n in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(n.original).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                            Text(n.translation).font(.system(size: 14, weight: .medium))
                        }
                        Spacer()
                        Button { copy(n.translation) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.plain)
                        Button { store.notes.removeAll { $0.id == n.id } } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var blockedTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.blocked.isEmpty {
                Spacer()
                Text("Chưa chặn app nào. Tick \"Không tự dịch ở …\" trên thẻ dịch để thêm.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(store.blocked) { a in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(a.name)
                            Text(a.id).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Bỏ chặn") { store.unblock(a.id) }
                    }
                }
            }
        }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func exportCSV() {
        let p = NSSavePanel()
        p.allowedContentTypes = [.commaSeparatedText]
        p.nameFieldStringValue = "sngtrans-ghichu.csv"
        if p.runModal() == .OK, let url = p.url {
            try? store.csv().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

enum ManagerWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: ManagerView()))
            w.title = "SngTrans: Ghi chú và chặn app"
            w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
