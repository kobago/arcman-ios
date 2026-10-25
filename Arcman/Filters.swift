import Foundation

struct Filters: Equatable {
    enum Media: String, CaseIterable {
        case photo, video, youtube, web, text
    }

    var folder = "all"
    var q = ""
    var tags: [Int] = []
    var from: Date?
    var to: Date?
    var media: Media?
    var author = ""
    var ascending = false

    var folderID: Int? { Int(folder).flatMap { $0 > 0 ? $0 : nil } }
    var isFiltered: Bool { !q.isEmpty || !tags.isEmpty || from != nil || to != nil || media != nil || !author.isEmpty }

    func query(cursor: String?, limit: Int = 30, calendar: Calendar = .current) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String) { items.append(URLQueryItem(name: name, value: value)) }
        let iso = ISO8601DateFormatter()
        if folder != "all" { add("folder", folder) }
        let keyword = q.trimmingCharacters(in: .whitespaces)
        if !keyword.isEmpty { add("q", keyword) }
        if !tags.isEmpty { add("tags", tags.map(String.init).joined(separator: ",")) }
        if let from { add("from", iso.string(from: calendar.startOfDay(for: from))) }
        if let to, let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) { add("to", iso.string(from: end)) }
        if let media { add("media", media.rawValue) }
        if !author.isEmpty { add("author", author) }
        add("order", ascending ? "asc" : "desc")
        if let cursor { add("cursor", cursor) }
        add("limit", String(limit))
        return items
    }
}
