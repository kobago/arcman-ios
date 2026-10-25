import Foundation

enum Server {
    static let appGroup = "group.io.github.kobago.arcman"
    static let defaults = UserDefaults(suiteName: appGroup) ?? .standard
    static let cookies = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: appGroup)

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = cookies
        config.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 1 << 30)
        return URLSession(configuration: config)
    }()

    static var baseURL: URL? {
        get { defaults.string(forKey: "serverURL").flatMap(URL.init(string:)) }
        set { defaults.set(newValue?.absoluteString, forKey: "serverURL") }
    }

    static func parse(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        if !text.contains("://") { text = "http://" + text }
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme), url.host() != nil else { return nil }
        return url
    }

    static func url(_ path: String) -> URL? {
        guard let base = baseURL else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    static func clearCookies() {
        for cookie in cookies.cookies ?? [] { cookies.deleteCookie(cookie) }
    }
}

struct APIError: Error {
    let status: Int
    let code: String
    var reason: String?
}

enum API {
    static var onUnauthorized: () -> Void = {}

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    @discardableResult
    static func send(_ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: Any]? = nil) async throws -> Data {
        guard let base = Server.baseURL, var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError(status: 0, code: "no_server")
        }
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await Server.session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let error = APIError(status: status, code: payload?["error"] as? String ?? "unknown", reason: payload?["reason"] as? String)
            if status == 401 && error.code == "unauthorized" { onUnauthorized() }
            throw error
        }
        return data
    }

    static func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try decoder.decode(T.self, from: try await send("GET", path, query: query))
    }

    static func login(_ password: String) async throws { try await send("POST", "/api/login", body: ["password": password]) }
    static func logout(all: Bool) async throws { try await send("POST", all ? "/api/logout-all" : "/api/logout") }

    static func session() async throws -> Bool {
        do {
            try await send("GET", "/api/session")
            return true
        } catch let error as APIError where error.status == 401 {
            return false
        }
    }

    static func tiles(_ query: [URLQueryItem]) async throws -> TilePage { try await get("/api/tiles", query: query) }

    static func save(_ urls: [String], folderID: Int?) async throws -> [SaveResult] {
        let data = try await send("POST", "/api/posts", body: ["urls": urls, "folder_id": folderID as Any? ?? NSNull()])
        return try decoder.decode([SaveResult].self, from: data)
    }

    static func progress(_ ids: [Int]) async throws -> [PostProgress] {
        try await get("/api/progress", query: [URLQueryItem(name: "ids", value: ids.map(String.init).joined(separator: ","))])
    }

    static func post(_ id: Int) async throws -> PostDetail { try await get("/api/posts/\(id)") }
    static func move(_ id: Int, to folderID: Int?) async throws { try await send("PATCH", "/api/posts/\(id)", body: ["folder_id": folderID as Any? ?? NSNull()]) }
    static func retry(_ id: Int) async throws { try await send("POST", "/api/posts/\(id)/retry") }
    static func delete(_ id: Int) async throws { try await send("DELETE", "/api/posts/\(id)") }

    static func setTags(_ id: Int, _ names: [String]) async throws -> [TagRef] {
        try decoder.decode([TagRef].self, from: try await send("PUT", "/api/posts/\(id)/tags", body: ["names": names]))
    }

    static func authors() async throws -> [Author] { try await get("/api/authors") }
    static func sidebar() async throws -> Sidebar { try await get("/api/sidebar") }
    static func createCategory(_ name: String) async throws { try await send("POST", "/api/categories", body: ["name": name]) }
    static func renameCategory(_ id: Int, _ name: String) async throws { try await send("PATCH", "/api/categories/\(id)", body: ["name": name]) }
    static func deleteCategory(_ id: Int) async throws { try await send("DELETE", "/api/categories/\(id)") }
    static func orderCategories(_ ids: [Int]) async throws { try await send("PUT", "/api/categories/order", body: ["ids": ids]) }
    static func createFolder(_ name: String, categoryID: Int?) async throws {
        try await send("POST", "/api/folders", body: ["name": name, "category_id": categoryID as Any? ?? NSNull()])
    }
    static func folder(_ id: Int) async throws -> FolderInfo { try await get("/api/folders/\(id)") }
    static func renameFolder(_ id: Int, _ name: String) async throws { try await send("PATCH", "/api/folders/\(id)", body: ["name": name]) }
    static func deleteFolder(_ id: Int) async throws { try await send("DELETE", "/api/folders/\(id)") }
    static func orderFolders(categoryID: Int?, _ ids: [Int]) async throws {
        try await send("PUT", "/api/folders/order", body: ["category_id": categoryID as Any? ?? NSNull(), "ids": ids])
    }

    static func tags(sort: String) async throws -> [Tag] { try await get("/api/tags", query: [URLQueryItem(name: "sort", value: sort)]) }
    static func renameTag(_ id: Int, _ name: String) async throws { try await send("PATCH", "/api/tags/\(id)", body: ["name": name]) }
    static func setTagColor(_ id: Int, _ color: String?) async throws { try await send("PATCH", "/api/tags/\(id)", body: ["color": color as Any? ?? NSNull()]) }
    static func deleteTag(_ id: Int) async throws { try await send("DELETE", "/api/tags/\(id)") }

    static func settings() async throws -> Settings { try await get("/api/settings") }
    static func saveSettings(fxtwitterBaseURL: String) async throws { try await send("PUT", "/api/settings", body: ["fxtwitter_base_url": fxtwitterBaseURL]) }
}

struct Tile: Decodable, Hashable, Identifiable {
    enum Kind: String, Decodable { case photo, video, gif, youtube, web, text, pending, failed }
    let postId: Int
    let kind: Kind
    let index: Int
    let count: Int
    let url: String
    let savedAt: String
    var src: String?
    var thumbnail: String?
    var width: Double?
    var height: Double?
    var duration: Double?
    var text: String?
    var authorName: String?
    var authorScreenName: String?
    var failure: String?

    var id: TileRef { TileRef(postId: postId, index: index) }
}

struct TileRef: Hashable, Identifiable {
    let postId: Int
    let index: Int

    var id: Self { self }
}

struct TilePage: Decodable {
    let tiles: [Tile]
    let nextCursor: String?
}

struct MediaView: Decodable, Hashable {
    enum Kind: String, Decodable { case photo, video, gif }
    let kind: Kind
    let src: String
    var thumbnail: String?
    var width: Double?
    var height: Double?
    var duration: Double?
}

struct StatusView: Decodable {
    struct Author: Decodable { let name: String; let screenName: String; var avatar: String? }
    struct Stats: Decodable { var likes, reposts, quotes, replies, views, bookmarks: Int? }
    struct Translation: Decodable { let text: String; var sourceLang: String? }
    struct Quote: Decodable { let available: Bool; var message: String?; var status: Box<StatusView>? }
    struct Card: Decodable { let url: String; var title, description, domain, image: String? }
    struct Poll: Decodable {
        struct Choice: Decodable { let label: String; let count: Int; let percentage: Double }
        var choices: [Choice]?
        var totalVotes: Int?
    }
    struct Note: Decodable { let text: String }
    struct Article: Decodable {
        struct Content: Decodable {
            struct Block: Decodable { var text: String? }
            var title: String?
            var previewText: String?
            var blocks: [Block]?
        }
        let content: Content
        let localUrls: [String: String]
    }

    let url: String
    let text: String
    var lang: String?
    var postedAt: Double?
    let author: Author
    let stats: Stats
    let media: [MediaView]
    var translation: Translation?
    var quote: Quote?
    var card: Card?
    var poll: Poll?
    var communityNote: Note?
    var article: Article?
}

// A struct cannot contain itself, so the quoted status goes through a class.
final class Box<T: Decodable>: Decodable {
    let value: T
    init(from decoder: Decoder) throws { value = try T(from: decoder) }
}

struct TagRef: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    var color: String?
}

struct VideoView: Decodable {
    struct Channel: Decodable { let name: String; let url: String }
    let id: String
    let url: String
    let shorts: Bool
    let title: String
    let channel: Channel
    var thumbnail: String?
}

struct PageView: Decodable {
    let url: String
    let title: String
    var description: String?
    var siteName: String?
    let host: String
    var image: MediaView?
    var icon: String?
}

struct PostDetail: Decodable {
    enum Source: String, Decodable { case x, youtube, web }
    enum State: String, Decodable { case pending, done, failed }
    let id: Int
    let source: Source
    let statusId: String
    let url: String
    let state: State
    var failure: String?
    var folderId: Int?
    let savedAt: String
    var tags: [TagRef]
    var status: StatusView?
    var video: VideoView?
    var page: PageView?
}

struct Folder: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    var categoryId: Int?
}

struct Category: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    var folders: [Folder]
}

struct Sidebar: Decodable {
    var categories: [Category]
    var uncategorized: [Folder]

    func folderLabel(_ id: Int?) -> String? {
        guard let id else { return nil }
        for c in categories {
            if let f = c.folders.first(where: { $0.id == id }) { return "\(c.name) / \(f.name)" }
        }
        return uncategorized.first { $0.id == id }?.name
    }

    func folderName(_ id: Int) -> String? {
        (categories.flatMap(\.folders) + uncategorized).first { $0.id == id }?.name
    }
}

struct FolderInfo: Decodable {
    let id: Int
    let name: String
    let postCount: Int
}

struct Tag: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    var color: String?
    let count: Int
}

struct Author: Decodable, Hashable {
    let screenName: String
    let name: String
    let count: Int
}

struct SaveResult: Decodable {
    enum Outcome: String, Decodable { case created, duplicate, invalidUrl = "invalid_url", unavailable }
    let url: String
    let outcome: Outcome
    var postId: Int?
    var reason: String?
}

struct PostProgress: Decodable {
    let postId: Int
    let state: PostDetail.State
    var progress: Double?
}

struct Settings: Decodable {
    struct Value: Decodable { let value: String; let source: String }
    let fxtwitterBaseUrl: Value
}
