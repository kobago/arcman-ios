import Foundation
import Testing
@testable import Arcman

struct LayoutTests {
    @Test func fillsEachRowToTheContainerWidth() {
        let rows = justify([1.0, 1.0, 1.0, 1.0, 1.0], ratio: { $0 }, width: 300, targetHeight: 100, gap: 0)
        #expect(rows.count == 2)
        #expect(rows[0].tiles.count == 3)
        #expect(rows[0].height == 100)
        #expect(rows[0].tiles.map(\.width).reduce(0, +) == 300)
    }

    @Test func leavesTheLastRowAtTheTargetHeight() {
        let rows = justify([1.0, 1.0, 1.0, 1.0], ratio: { $0 }, width: 300, targetHeight: 100, gap: 0)
        #expect(rows[1].height == 100)
        #expect(rows[1].tiles.count == 1)
    }

    @Test func accountsForGapsBetweenTiles() {
        let rows = justify([2.0, 2.0], ratio: { $0 }, width: 404, targetHeight: 100, gap: 4)
        #expect(rows.count == 1)
        #expect(rows[0].height == 100)
        #expect(rows[0].tiles.map(\.width).reduce(0, +) + 4 == 404)
    }

    @Test func clampsExtremeAspectRatios() {
        #expect(clampedRatio(1000, 100) == 2.5)
        #expect(clampedRatio(100, 1000) == 0.5)
        #expect(clampedRatio(nil, 100) == 1)
        #expect(clampedRatio(0, 0) == 1)
    }
}

struct FiltersTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func value(_ items: [URLQueryItem], _ name: String) -> String? {
        items.first { $0.name == name }?.value
    }

    @Test func sendsOnlyTheOrderAndLimitByDefault() {
        let items = Filters().query(cursor: nil)
        #expect(items.map(\.name) == ["order", "limit"])
        #expect(value(items, "order") == "desc")
        #expect(value(items, "limit") == "30")
    }

    @Test func sendsTheEndDateAsTheNextLocalMidnight() {
        let day = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 15))!
        let items = Filters(from: day, to: day).query(cursor: nil, calendar: tokyo)
        #expect(value(items, "from") == "2026-10-23T15:00:00Z")
        #expect(value(items, "to") == "2026-10-24T15:00:00Z")
    }

    @Test func sendsEveryCondition() {
        let filters = Filters(folder: "7", q: "  cat ", tags: [3, 5], media: .video, author: "jack", ascending: true)
        let items = filters.query(cursor: "abc", limit: 10)
        #expect(value(items, "folder") == "7")
        #expect(value(items, "q") == "cat")
        #expect(value(items, "tags") == "3,5")
        #expect(value(items, "media") == "video")
        #expect(value(items, "author") == "jack")
        #expect(value(items, "order") == "asc")
        #expect(value(items, "cursor") == "abc")
        #expect(value(items, "limit") == "10")
        #expect(filters.folderID == 7)
        #expect(filters.isFiltered)
    }

    @Test func treatsAllAndUnsortedAsNoFolderID() {
        #expect(Filters(folder: "all").folderID == nil)
        #expect(Filters(folder: "unsorted").folderID == nil)
    }
}

struct FormatTests {
    @Test func normalizesTagKeysLikeTheServer() {
        #expect(normalizeTagKey("  #Ｓｗｉｆｔ ") == "swift")
        #expect(normalizeTagKey("##猫") == "猫")
        #expect(normalizeTagKey("ｱｲｳ") == "アイウ")
    }

    @Test func formatsDurations() {
        #expect(formatDuration(5) == "0:05")
        #expect(formatDuration(65.4) == "1:05")
        #expect(formatDuration(3725) == "1:02:05")
    }

    @Test func readsSwipeDirections() {
        #expect(swipeDirection(dx: -80, dy: 10) == .left)
        #expect(swipeDirection(dx: 5, dy: -90) == .up)
        #expect(swipeDirection(dx: 60, dy: 50) == nil)
        #expect(swipeDirection(dx: 20, dy: 20) == nil)
    }

    @Test func acceptsServerAddressesAsTyped() {
        #expect(Server.parse("100.64.0.1:3000")?.absoluteString == "http://100.64.0.1:3000")
        #expect(Server.parse(" https://arcman.example/ ")?.absoluteString == "https://arcman.example")
        #expect(Server.parse("ftp://x") == nil)
        #expect(Server.parse("") == nil)
    }
}
