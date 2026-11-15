import Foundation

struct Meaning { let pos: String; let words: [String] }

struct TranslationResult {
    var text: String
    var detected: String
    var target: String
    var meanings: [Meaning]
}

enum TranslateError: Error { case bad, rateLimited }

/// Gọi endpoint dịch miễn phí của Google (không cần key), có cache và dự phòng nhiều máy chủ.
actor Translator {
    static let shared = Translator()

    private var cache: [String: TranslationResult] = [:]
    private var order: [String] = []
    private let hosts = ["translate.googleapis.com", "translate.google.com", "translate.google.com.vn"]
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.httpAdditionalHeaders = ["User-Agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"]
        return c
    }()

    func translate(_ q: String, to tl: String) async throws -> TranslationResult {
        let key = tl + "|" + q
        if let hit = cache[key] { return hit }
        var r = try await fetch(q, tl)
        // Chữ đã ở đúng ngôn ngữ đích thì dịch sang tiếng Anh (hoặc tiếng Việt nếu đích là Anh)
        if Self.base(r.detected) == Self.base(tl) {
            let alt = Self.base(tl) == "en" ? "vi" : "en"
            if let r2 = try? await fetch(q, alt) { r = r2 }
        }
        cache[key] = r
        order.append(key)
        if order.count > 200 { cache.removeValue(forKey: order.removeFirst()) }
        return r
    }

    static func base(_ code: String) -> String {
        String(code.split(separator: "-").first ?? "").lowercased()
    }

    private func fetch(_ q: String, _ tl: String) async throws -> TranslationResult {
        var lastError: Error = TranslateError.bad
        let enc = q.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        for host in hosts {
            var c = URLComponents()
            c.scheme = "https"; c.host = host; c.path = "/translate_a/single"
            c.percentEncodedQuery = "client=gtx&sl=auto&tl=\(tl)&dt=t&dt=bd&q=\(enc)"
            guard let url = c.url else { continue }
            do {
                let (data, resp) = try await session.data(from: url)
                if let h = resp as? HTTPURLResponse, h.statusCode == 429 {
                    lastError = TranslateError.rateLimited
                    continue
                }
                return try parse(data, tl)
            } catch { lastError = error }
        }
        throw lastError
    }

    private func parse(_ data: Data, _ tl: String) throws -> TranslationResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [Any],
              let segs = root.first as? [Any] else { throw TranslateError.bad }
        var text = ""
        for s in segs { if let a = s as? [Any], let t = a.first as? String { text += t } }
        guard !text.isEmpty else { throw TranslateError.bad }

        var meanings: [Meaning] = []
        if root.count > 1, let dict = root[1] as? [Any] {
            for e in dict.prefix(4) {
                if let a = e as? [Any], a.count > 1, let pos = a[0] as? String, let ws = a[1] as? [Any] {
                    let w = ws.compactMap { $0 as? String }.prefix(6)
                    if !w.isEmpty { meanings.append(Meaning(pos: pos, words: Array(w))) }
                }
            }
        }
        let detected = root.count > 2 ? (root[2] as? String ?? "auto") : "auto"
        return TranslationResult(text: text, detected: detected, target: tl, meanings: meanings)
    }
}
