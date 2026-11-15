import Foundation

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var original: String
    var translation: String
    var from: String
    var to: String
    var date = Date()
}

struct BlockedApp: Codable, Identifiable, Equatable {
    var id: String      // bundle id
    var name: String
}

/// Lưu ghi chú và danh sách app bị chặn ở ~/Library/Application Support/SngTrans
final class Store: ObservableObject {
    static let shared = Store()

    @Published var notes: [Note] = [] { didSet { save(notes, "notes.json") } }
    @Published var blocked: [BlockedApp] = [] { didSet { save(blocked, "blocked.json") } }

    private let dir: URL

    private init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SngTrans")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        notes = load("notes.json") ?? []
        blocked = load("blocked.json") ?? []
    }

    func isBlocked(_ id: String?) -> Bool {
        guard let id else { return false }
        return blocked.contains { $0.id == id }
    }

    func block(_ id: String, name: String) {
        if !isBlocked(id) { blocked.append(BlockedApp(id: id, name: name)) }
    }

    func unblock(_ id: String) { blocked.removeAll { $0.id == id } }

    func addNote(_ n: Note) {
        if notes.contains(where: { $0.original == n.original && $0.translation == n.translation }) { return }
        notes.insert(n, at: 0)
    }

    /// CSV có BOM để Excel đọc đúng tiếng Việt.
    func csv() -> String {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let f = ISO8601DateFormatter()
        var out = "\u{FEFF}Gốc,Dịch,Từ,Sang,Ngày\n"
        for n in notes {
            out += [q(n.original), q(n.translation), q(n.from), q(n.to), q(f.string(from: n.date))]
                .joined(separator: ",") + "\n"
        }
        return out
    }

    private func save<T: Encodable>(_ v: T, _ name: String) {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        try? e.encode(v).write(to: dir.appendingPathComponent(name), options: .atomic)
    }

    private func load<T: Decodable>(_ name: String) -> T? {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: d)
    }
}
