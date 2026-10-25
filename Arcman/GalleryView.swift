import SwiftUI

struct GalleryView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("gallerySize") private var size = GallerySize.defaultSize
    @State private var drawerOpen = false
    @State private var searchOpen = false
    @State private var saveOpen = false
    @State private var q = ""
    @State private var width: CGFloat = 0

    private var gallery: GalleryModel { app.gallery }

    private var title: String {
        let folder = gallery.filters.folder
        if folder == "unsorted" { return t("nav.unsorted") }
        if let id = gallery.filters.folderID { return app.sidebar.folderName(id) ?? "" }
        return t("nav.all")
    }

    private var destination: String {
        gallery.filters.folderID.flatMap { app.sidebar.folderLabel($0) } ?? t("nav.unsorted")
    }

    var body: some View {
        @Bindable var gallery = gallery
        VStack(spacing: 0) {
            topBar
            if searchOpen { searchField }
            if saveOpen {
                SaveSheet(folderID: gallery.filters.folderID, destination: destination) { saveOpen = false }
            }
            FilterBar(size: $size)
            content
        }
        .background(.bg)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { SaveToastsView() }
        .overlay { Drawer(open: $drawerOpen) }
        .fullScreenCover(item: $gallery.opened) { start in
            DetailView(current: start)
        }
        .task(id: gallery.filters) { await gallery.reload() }
        .task(id: gallery.hasPending) {
            while gallery.hasPending {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await gallery.refresh()
            }
        }
        .task {
            await app.refreshSidebar()
            await app.refreshTags()
        }
        .task(id: q) {
            guard q != gallery.filters.q else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            gallery.filters.q = q
        }
        .onChange(of: gallery.filters.q) { _, new in q = new }
    }

    private var topBar: some View {
        HStack(spacing: 4) {
            IconButton(systemImage: "line.3.horizontal", label: t("nav.open")) { drawerOpen = true }
            Text(title)
                .font(.plex(17, .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(systemImage: "magnifyingglass", label: t("search.label")) {
                withAnimation(.easeOut(duration: 0.15)) { searchOpen.toggle() }
            }
            IconButton(systemImage: "plus", label: t("save.open"), primary: true) {
                withAnimation(.easeOut(duration: 0.15)) { saveOpen.toggle() }
            }
        }
        .padding(.horizontal, 6)
        .frame(minHeight: 56)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.muted)
            TextField("", text: $q, prompt: Text(t("search.placeholder")).foregroundStyle(.muted))
                .font(.plex(16))
                .submitLabel(.search)
                .accessibilityLabel(t("search.label"))
            if !q.isEmpty {
                Button { q = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.muted) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(.raised, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.line))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let error = gallery.error, gallery.tiles.isEmpty {
            empty(errorMessage(error))
        } else if gallery.loaded && gallery.tiles.isEmpty {
            empty(gallery.filters.isFiltered ? t("gallery.noMatch") : t("gallery.empty"))
        } else {
            grid
        }
    }

    private func empty(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .foregroundStyle(.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
        }
        .refreshable { await gallery.reload() }
    }

    private var grid: some View {
        let gap: CGFloat = 2
        let rows = width > 0
            ? justify(gallery.tiles, ratio: { clampedRatio($0.width, $0.height) }, width: width, targetHeight: GallerySize.rowHeight(size), gap: gap)
            : []
        return ScrollView {
            LazyVStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: gap) {
                        ForEach(rows[i].tiles, id: \.item.id) { placed in
                            TileView(tile: placed.item, size: CGSize(width: placed.width, height: rows[i].height))
                                .onTapGesture { gallery.opened = placed.item.id }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if gallery.hasMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear { Task { await gallery.loadMore() } }
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 48)
            .onGeometryChange(for: CGFloat.self) { $0.size.width - 4 } action: { width = $0 }
        }
        .refreshable { await gallery.refresh() }
        .simultaneousGesture(
            MagnifyGesture().onEnded { value in
                if value.magnification > 1.15 { size = min(GallerySize.max, size + 1) }
                if value.magnification < 0.87 { size = max(0, size - 1) }
            }
        )
    }
}

struct TileView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.displayScale) private var scale
    let tile: Tile
    let size: CGSize
    @State private var retrying = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            body(for: tile)
                .frame(width: size.width, height: size.height)
            if tile.count > 1 && tile.kind != .video {
                Badge { Text("\(tile.index + 1)/\(tile.count)") }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(.raised)
        .clipShape(.rect(cornerRadius: 2))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(tile.count > 1 ? "\(t("tile.open")) (\(tile.index + 1)/\(tile.count))" : t("tile.open"))
    }

    private var maxPixel: CGFloat { max(size.width, size.height) * scale }

    @ViewBuilder
    private func body(for tile: Tile) -> some View {
        switch tile.kind {
        case .photo:
            RemoteImage(path: tile.src, maxPixel: maxPixel)
        case .gif:
            ZStack {
                RemoteImage(path: tile.thumbnail, maxPixel: maxPixel)
                if let src = tile.src { LoopingVideo(src: src) }
            }
        case .video:
            RemoteImage(path: tile.thumbnail, maxPixel: maxPixel)
                .overlay(alignment: .topTrailing) {
                    Badge {
                        Image(systemName: "play.fill").font(.system(size: 8))
                        if let duration = tile.duration { Text(formatDuration(duration)) }
                    }
                }
        case .youtube:
            RemoteImage(path: tile.src, maxPixel: maxPixel)
                .overlay(alignment: .topTrailing) { Badge { Image(systemName: "play.rectangle").font(.system(size: 11)) } }
                .overlay(alignment: .bottom) { caption(tile.text ?? "") }
        case .web:
            let lines = (tile.text ?? "").split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let title = lines.first.map(String.init) ?? ""
            if tile.src != nil {
                RemoteImage(path: tile.src, maxPixel: maxPixel)
                    .overlay(alignment: .topTrailing) { Badge { Image(systemName: "link").font(.system(size: 10)) } }
                    .overlay(alignment: .bottom) { caption(title) }
            } else {
                textTile {
                    Text("\(Text(title).font(.plex(11.5, .semibold)))\(lines.count > 1 ? "\n" + lines[1] : "")")
                } author: {
                    Label(tile.authorName ?? "", systemImage: "link").labelStyle(TightLabelStyle())
                }
            }
        case .text:
            textTile {
                Text(tile.text ?? "")
            } author: {
                Text("\(tile.authorName ?? "") \(Text("@\(tile.authorScreenName ?? "")").foregroundStyle(.muted))")
            }
        case .pending:
            VStack(spacing: 8) {
                Spinner()
                Text(t("tile.pending"))
            }
            .font(.plex(12.5))
            .foregroundStyle(.muted)
        case .failed:
            VStack(spacing: 6) {
                Text(t("tile.failed")).foregroundStyle(.danger)
                if let failure = tile.failure { Text(t("failure.\(failure)")).foregroundStyle(.muted) }
                Text(hostOf(tile.url)).foregroundStyle(.muted).lineLimit(1)
                Button {
                    retrying = true
                    Task {
                        try? await API.retry(tile.postId)
                        await app.gallery.refresh()
                        retrying = false
                    }
                } label: {
                    Label(t("common.retry"), systemImage: "arrow.clockwise").labelStyle(TightLabelStyle())
                }
                .buttonStyle(OutlineButtonStyle(small: true))
                .disabled(retrying)
            }
            .font(.plex(12))
            .multilineTextAlignment(.center)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(.dangerFill, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.plex(12))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }

    private func textTile(@ViewBuilder text: () -> some View, @ViewBuilder author: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            text()
                .font(.plex(11.5))
                .lineSpacing(2)
                .lineLimit(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            author()
                .font(.plex(10.5))
                .lineLimit(1)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(.line))
    }
}
