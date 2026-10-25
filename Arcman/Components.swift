import AVFoundation
import ImageIO
import SwiftUI
import UIKit

enum ImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func cached(_ path: String, maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: "\(path)#\(Int(maxPixel))" as NSString)
    }

    static func load(_ path: String, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(path)#\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let url = Server.url(path),
              let (data, _) = try? await Server.session.data(for: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)),
              let image = await decode(data, maxPixel: maxPixel)
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    // Decoding originals at full size would hold several hundred MB for one screen of tiles.
    @concurrent
    nonisolated static func decode(_ data: Data, maxPixel: CGFloat) async -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

struct RemoteImage: View {
    let path: String?
    var contentMode: ContentMode = .fill
    var maxPixel: CGFloat = 600
    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image = image ?? path.flatMap({ ImageLoader.cached($0, maxPixel: maxPixel) }) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                }
            }
            .clipped()
            .task(id: path) {
            guard let path else { return }
            image = await ImageLoader.load(path, maxPixel: maxPixel)
        }
    }
}

func playerItem(_ path: String) -> AVPlayerItem? {
    guard let url = Server.url(path) else { return nil }
    let cookies = Server.cookies.cookies(for: url) ?? []
    return AVPlayerItem(asset: AVURLAsset(url: url, options: [AVURLAssetHTTPCookiesKey: cookies]))
}

struct LoopingVideo: UIViewRepresentable {
    let src: String
    var fill = true

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var looper: AVPlayerLooper?
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        guard let item = playerItem(src) else { return view }
        let player = AVQueuePlayer()
        player.isMuted = true
        view.looper = AVPlayerLooper(player: player, templateItem: item)
        view.playerLayer.player = player
        player.play()
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.playerLayer.player?.pause()
    }
}

struct Spinner: View {
    var size: CGFloat = 26
    @State private var spinning = false

    var body: some View {
        Circle()
            .stroke(.line, lineWidth: 2.5)
            .overlay(Circle().trim(from: 0, to: 0.25).stroke(.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

struct Badge<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 4) { content }
            .font(.mono(10.5))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(.black.opacity(0.6), in: .capsule)
            .padding(6)
    }
}

struct ChipStatic: View {
    let label: String
    var icon = "folder"

    var body: some View {
        Label(label, systemImage: icon)
            .labelStyle(TightLabelStyle())
            .font(.plex(12.5))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(.selected, in: .rect(cornerRadius: 6))
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] = []
        var current: [Int] = [], x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !current.isEmpty && x + size.width > width {
                rows.append((current, y, x - spacing, height))
                y += height + spacing
                current = []; x = 0; height = 0
            }
            current.append(index)
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !current.isEmpty { rows.append((current, y, x - spacing, height)) }
        return rows
    }
}

struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.plex(12)).foregroundStyle(.muted)
    }
}

struct ErrorText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.plex(12.5)).foregroundStyle(.danger)
    }
}

struct IconButton: View {
    let systemImage: String
    let label: String
    var primary = false
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: primary ? .semibold : .regular))
                .foregroundStyle(primary ? .accentInk : .text)
                .frame(width: size, height: size)
                .background(primary ? Color.accent : Color.clear, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
