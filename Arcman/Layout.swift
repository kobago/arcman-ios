import CoreGraphics

struct Row<T> {
    struct Placed {
        let item: T
        let width: CGFloat
    }

    let height: CGFloat
    let tiles: [Placed]
}

func clampedRatio(_ width: Double?, _ height: Double?) -> Double {
    guard let width, let height, width > 0, height > 0 else { return 1 }
    return min(2.5, max(0.5, width / height))
}

func justify<T>(_ items: [T], ratio ratioOf: (T) -> Double, width: CGFloat, targetHeight: CGFloat, gap: CGFloat) -> [Row<T>] {
    var rows: [Row<T>] = []
    var pending: [(item: T, ratio: CGFloat)] = []
    var ratioSum: CGFloat = 0
    func close(_ height: CGFloat) {
        rows.append(Row(height: height, tiles: pending.map { .init(item: $0.item, width: $0.ratio * height) }))
        pending = []
        ratioSum = 0
    }
    for item in items {
        let ratio = CGFloat(ratioOf(item))
        pending.append((item, ratio))
        ratioSum += ratio
        let gaps = gap * CGFloat(pending.count - 1)
        if ratioSum * targetHeight + gaps >= width {
            close((width - gaps) / ratioSum)
        }
    }
    if !pending.isEmpty { close(targetHeight) }
    return rows
}

enum GallerySize {
    static let heights: [CGFloat] = [60, 90, 120, 170, 240]
    static let defaultSize = 2
    static var max: Int { heights.count - 1 }

    static func rowHeight(_ size: Int) -> CGFloat {
        heights.indices.contains(size) ? heights[size] : heights[defaultSize]
    }
}
