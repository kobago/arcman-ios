import AVKit
import Photos
import SwiftUI
import WebKit

private let sheetOpenTop: CGFloat = 210
private let sheetHandle: CGFloat = 28
private let sheetSnap: CGFloat = 40
private let slideGap: CGFloat = 16

struct DetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State var current: TileRef
    @State private var sheetOpen = false
    @State private var immersive = false
    @State private var offset: CGFloat = 0
    @State private var axis: Axis?
    @State private var sliding = false
    @State private var dragTop: CGFloat?
    @State private var loadError: Error?
    @State private var notice: String?

    private var gallery: GalleryModel { app.gallery }
    private var position: Int? { gallery.tiles.firstIndex { $0.id == current } }
    private var prev: Tile? { position.flatMap { $0 > 0 ? gallery.tiles[$0 - 1] : nil } }
    private var next: Tile? { position.flatMap { $0 + 1 < gallery.tiles.count ? gallery.tiles[$0 + 1] : nil } }
    private var post: PostDetail? { gallery.posts[current.postId] }
    private var media: [MediaView] { post?.status?.media ?? [] }
    private var currentMedia: MediaView? { media.indices.contains(current.index) ? media[current.index] : nil }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .top) {
                stage(width: geo.size.width)
                    .frame(height: immersive ? height + geo.safeAreaInsets.bottom : height - sheetHandle)
                sheet(height: height)
            }
        }
        .background(Color.stage.ignoresSafeArea())
        .foregroundStyle(.stageText)
        .statusBarHidden(immersive)
        .task(id: current) { await load() }
        .onChange(of: position) { _, position in
            if let position, position >= gallery.tiles.count - 3, gallery.hasMore {
                Task { await gallery.loadMore() }
            }
        }
    }


    private func stage(width: CGFloat) -> some View {
        ZStack {
            ZStack {
                if let prev { TilePreview(tile: prev).offset(x: -(width + slideGap)) }
                currentSlide
                if let next { TilePreview(tile: next).offset(x: width + slideGap) }
            }
            .offset(x: offset)

            if !immersive {
                VStack {
                    topBar
                    Spacer()
                }
                HStack {
                    if let prev { navButton("chevron.left", t("detail.prev")) { slide(to: prev, dir: -1, width: width) } }
                    Spacer()
                    if let next { navButton("chevron.right", t("detail.next")) { slide(to: next, dir: 1, width: width) } }
                }
                .padding(.horizontal, 6)
            }
            if let notice {
                Text(notice)
                    .font(.plex(13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: .capsule)
                    .transition(.opacity)
            }
        }
        .clipped()
        .contentShape(.rect)
        .onTapGesture {
            if sheetOpen { sheetOpen = false } else { immersive.toggle() }
        }
        .gesture(swipe(width: width))
    }

    private var topBar: some View {
        HStack {
            stageButton("xmark", t("common.close")) { dismiss() }
            Spacer()
            if media.count > 1 {
                Text("\(current.index + 1) / \(media.count)")
                    .font(.mono(13))
                    .foregroundStyle(Color(hex: 0xd4d7db))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: .capsule)
            }
            Spacer()
            if let currentMedia {
                stageButton("arrow.down.to.line", t("detail.download")) {
                    Task { await saveToPhotos(currentMedia) }
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(6)
    }

    @ViewBuilder
    private var currentSlide: some View {
        if let loadError, post == nil {
            message { Text(errorMessage(loadError)) }
        } else if let post {
            if post.state != .done {
                message {
                    Text(t(post.state == .pending ? "detail.pending" : "detail.failed"))
                    if let failure = post.failure { Text(t("failure.\(failure)")).font(.plex(12.5)) }
                    if post.state == .failed {
                        Button {
                            Task {
                                try? await API.retry(post.id)
                                _ = try? await gallery.loadPost(post.id)
                                await gallery.refresh()
                            }
                        } label: {
                            Label(t("common.retry"), systemImage: "arrow.clockwise").labelStyle(TightLabelStyle())
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }
                }
            } else if let video = post.video {
                YouTubePlayer(id: video.id)
                    .aspectRatio(video.shorts ? 9 / 16 : 16 / 9, contentMode: .fit)
            } else if let page = post.page {
                if let image = page.image {
                    StageImage(path: image.src)
                } else {
                    StageText(text: page.title)
                }
            } else if let currentMedia {
                switch currentMedia.kind {
                case .photo: StageImage(path: currentMedia.src)
                case .gif: LoopingVideo(src: currentMedia.src, fill: false)
                case .video: DetailVideo(src: currentMedia.src).id(currentMedia.src)
                }
            } else {
                StageText(text: post.status?.text ?? "")
            }
        } else if let tile = gallery.tiles.first(where: { $0.id == current }) {
            TilePreview(tile: tile)
        } else {
            Spinner()
        }
    }

    private func message(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 8) { content() }
            .foregroundStyle(Color(hex: 0xa3a9b0))
            .multilineTextAlignment(.center)
            .padding(24)
    }

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !sliding else { return }
                let dx = value.translation.width, dy = value.translation.height
                if axis == nil { axis = abs(dx) > abs(dy) ? .horizontal : .vertical }
                if axis == .horizontal { offset = (dx < 0 ? next : prev) != nil ? dx : dx / 3 }
            }
            .onEnded { value in
                defer { axis = nil }
                guard !sliding else { return }
                let dx = value.translation.width, dy = value.translation.height
                if axis == .horizontal {
                    let far = abs(dx) > min(80, width / 5) || abs(value.predictedEndTranslation.width) > width / 2
                    if far && dx < 0, let next { slide(to: next, dir: 1, width: width) }
                    else if far && dx > 0, let prev { slide(to: prev, dir: -1, width: width) }
                    else { withAnimation(.easeOut(duration: 0.25)) { offset = 0 } }
                    return
                }
                switch swipeDirection(dx: dx, dy: dy) {
                case .up:
                    sheetOpen = true
                    immersive = false
                case .down:
                    if sheetOpen { sheetOpen = false } else { dismiss() }
                default: break
                }
            }
    }

    private func slide(to tile: Tile, dir: CGFloat, width: CGFloat) {
        guard !sliding else { return }
        sliding = true
        withAnimation(.easeOut(duration: 0.25)) {
            offset = -dir * (width + slideGap)
        } completion: {
            current = tile.id
            offset = 0
            sliding = false
        }
    }


    private func sheet(height: CGFloat) -> some View {
        let closedTop = height - sheetHandle
        let top = dragTop ?? (sheetOpen ? sheetOpenTop : closedTop)
        let expanded = sheetOpen || dragTop != nil
        return VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: 0x5b6168))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .frame(height: sheetHandle)
                .contentShape(.rect)
                .onTapGesture { sheetOpen.toggle() }
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            let base = sheetOpen ? sheetOpenTop : closedTop
                            dragTop = min(closedTop, max(sheetOpenTop, base + value.translation.height))
                        }
                        .onEnded { value in
                            if value.translation.height < -sheetSnap { sheetOpen = true }
                            if value.translation.height > sheetSnap { sheetOpen = false }
                            dragTop = nil
                        }
                )
                .accessibilityLabel(t("detail.swipeHint"))
                .accessibilityAddTraits(.isButton)
            if expanded, let post {
                ScrollView {
                    PostPanel(post: post) { dismiss() }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 28)
                }
                .foregroundStyle(.text)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, height - top), alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
                .fill(expanded ? AnyShapeStyle(.panel) : AnyShapeStyle(Color(red: 5 / 255, green: 6 / 255, blue: 6 / 255).opacity(0.78)))
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: immersive ? height + 60 : top)
        .animation(dragTop == nil ? .easeOut(duration: 0.25) : nil, value: top)
        .animation(.easeOut(duration: 0.25), value: immersive)
    }


    private func load() async {
        loadError = nil
        do {
            var post = try await gallery.loadPost(current.postId)
            for tile in [prev, next].compactMap(\.self) where gallery.posts[tile.postId] == nil {
                Task { try? await gallery.loadPost(tile.postId) }
            }
            while post.state == .pending {
                try await Task.sleep(for: .seconds(2))
                post = try await gallery.loadPost(current.postId)
            }
        } catch is CancellationError {
        } catch {
            loadError = error
        }
    }

    private func saveToPhotos(_ media: MediaView) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return show(t("detail.photosDenied")) }
        guard let url = Server.url(media.src), let (data, _) = try? await Server.session.data(from: url) else {
            return show(t("error.generic"))
        }
        do {
            try await addToPhotos(data, photo: media.kind == .photo)
            show(t("detail.savedToPhotos"))
        } catch {
            show(t("error.generic"))
        }
    }

    private func show(_ text: String) {
        withAnimation { notice = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if notice == text { notice = nil } }
        }
    }

    private func stageButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.45), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func navButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.45), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// Photos runs the change block on its own queue, so the block must not inherit main-actor isolation.
nonisolated private func addToPhotos(_ data: Data, photo: Bool) async throws {
    if photo {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    } else {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: file, options: nil)
        }
    }
}

enum Swipe { case left, right, up, down }

func swipeDirection(dx: CGFloat, dy: CGFloat, threshold: CGFloat = 50) -> Swipe? {
    let ax = abs(dx), ay = abs(dy)
    if max(ax, ay) < threshold { return nil }
    if ax > ay * 1.5 { return dx < 0 ? .left : .right }
    if ay > ax * 1.5 { return dy < 0 ? .up : .down }
    return nil
}

private struct StageImage: View {
    let path: String

    var body: some View {
        RemoteImage(path: path, contentMode: .fit, maxPixel: 2400)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StageText: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.plex(20))
                .lineSpacing(6)
                .padding(32)
                .frame(maxWidth: 560)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TilePreview: View {
    let tile: Tile

    var body: some View {
        switch tile.kind {
        case .photo, .youtube: StageImage(path: tile.src ?? "")
        case .video, .gif: StageImage(path: tile.thumbnail ?? "")
        case .web:
            if let src = tile.src { StageImage(path: src) } else { StageText(text: tile.text?.components(separatedBy: "\n").first ?? "") }
        case .text: StageText(text: tile.text ?? "")
        case .pending, .failed: Color.clear
        }
    }
}

private struct DetailVideo: View {
    let src: String
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                guard player == nil, let item = playerItem(src) else { return }
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                let player = AVPlayer(playerItem: item)
                self.player = player
                player.play()
            }
            .onDisappear {
                player?.pause()
                try? AVAudioSession.sharedInstance().setCategory(.ambient)
            }
    }
}

private struct YouTubePlayer: UIViewRepresentable {
    let id: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        // YouTube refuses embeds without a referrer, so the frame is served as if from the arcman server like the web page does.
        web.loadHTMLString("""
            <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>html,body{margin:0;height:100%;background:#070808}iframe{border:0;width:100%;height:100%}</style>
            <iframe src="https://www.youtube-nocookie.com/embed/\(id)?autoplay=1&playsinline=1&rel=0"
              allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>
            """, baseURL: Server.baseURL)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}
