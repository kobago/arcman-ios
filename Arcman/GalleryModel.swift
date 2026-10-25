import Foundation

@Observable
final class GalleryModel {
    var filters = Filters()
    private(set) var tiles: [Tile] = []
    private(set) var nextCursor: String?
    private(set) var loaded = false
    private(set) var error: Error?
    private(set) var loadingMore = false
    private var pages = 0
    private var generation = 0
    var posts: [Int: PostDetail] = [:]
    var opened: TileRef?

    var hasMore: Bool { nextCursor != nil }
    var hasPending: Bool { tiles.contains { $0.kind == .pending } }

    func reset() {
        filters = Filters()
        tiles = []
        posts = [:]
        nextCursor = nil
        loaded = false
        pages = 0
    }

    func reload() async {
        generation += 1
        let mine = generation
        do {
            let page = try await API.tiles(filters.query(cursor: nil))
            guard mine == generation else { return }
            tiles = page.tiles
            nextCursor = page.nextCursor
            pages = 1
            error = nil
        } catch {
            guard mine == generation, !(error is CancellationError) else { return }
            self.error = error
        }
        loaded = true
    }

    func refresh() async {
        let mine = generation
        var all: [Tile] = []
        var cursor: String?
        do {
            for _ in 0..<max(pages, 1) {
                let page = try await API.tiles(filters.query(cursor: cursor))
                all += page.tiles
                cursor = page.nextCursor
                if cursor == nil { break }
            }
        } catch {
            return
        }
        guard mine == generation else { return }
        tiles = all
        nextCursor = cursor
    }

    func loadMore() async {
        guard let cursor = nextCursor, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let mine = generation
        guard let page = try? await API.tiles(filters.query(cursor: cursor)), mine == generation else { return }
        tiles += page.tiles
        nextCursor = page.nextCursor
        pages += 1
    }

    @discardableResult
    func loadPost(_ id: Int) async throws -> PostDetail {
        let post = try await API.post(id)
        posts[id] = post
        return post
    }

    func removePost(_ id: Int) {
        tiles.removeAll { $0.postId == id }
        posts[id] = nil
    }
}
