import Foundation

struct QuranWord: Identifiable, Hashable {
    var id: Int { position }
    let position: Int
    let text: String
    let translation: String
    let transliteration: String
}

extension QuranAPI {
    /// Word-by-word for a single ayah (Quran.com words + EN gloss).
    func words(key: String) async throws -> [QuranWord] {
        let parts = key.split(separator: ":")
        guard parts.count == 2 else { throw APIError.badURL }
        let url = URL(string: "https://api.quran.com/api/v4/verses/by_key/\(key)?language=en&words=true&word_fields=text_uthmani,translation,transliteration")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let verse = json?["verse"] as? [String: Any] else { throw APIError.decode }
        let list = verse["words"] as? [[String: Any]] ?? []
        return list.compactMap { w in
            let pos = w["position"] as? Int ?? 0
            let text = w["text_uthmani"] as? String ?? w["text"] as? String ?? ""
            if (w["char_type_name"] as? String) == "end" { return nil }
            let tr: String
            if let t = w["translation"] as? [String: Any] {
                tr = HTMLStrip.clean(t["text"] as? String ?? "")
            } else {
                tr = ""
            }
            let tl: String
            if let t = w["transliteration"] as? [String: Any] {
                tl = t["text"] as? String ?? ""
            } else {
                tl = ""
            }
            guard !text.isEmpty else { return nil }
            return QuranWord(position: pos, text: text, translation: tr, transliteration: tl)
        }
    }
}
