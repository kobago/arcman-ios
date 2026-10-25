import SwiftUI

struct PostPanel: View {
    @Environment(AppModel.self) private var app
    let post: PostDetail
    let onDeleted: () -> Void
    @State private var busy = false
    @State private var error: String?
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let status = post.status { StatusContent(status: status, openLabel: post.source == .pixiv ? t("detail.openOnPixiv") : nil) }
            if let video = post.video { videoInfo(video) }
            if let page = post.page { pageInfo(page) }
            if post.state == .failed, let url = URL(string: post.url) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(post.url).lineLimit(1)
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.plex(12.5))
                }
            }
            dates
            Rectangle().fill(.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(t("detail.folder"))
                folderPicker
            }
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(t("detail.tags"))
                TagInput(value: post.tags, busy: busy) { names in setTags(names) }
            }
            if let error { ErrorText(error) }
            Button {
                confirmDelete = true
            } label: {
                Label(t("detail.delete"), systemImage: "trash").labelStyle(TightLabelStyle()).frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlineButtonStyle(danger: true))
            .padding(.top, 8)
        }
        .alert(t("detail.deleteTitle"), isPresented: $confirmDelete) {
            Button(t("common.cancel"), role: .cancel) {}
            Button(t("common.delete"), role: .destructive, action: delete)
        } message: {
            Text(t("detail.deleteBody"))
        }
    }

    private var dates: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            if let postedAt = post.status?.postedAt {
                GridRow {
                    Text(t("detail.postedAt")).foregroundStyle(.muted)
                    Text(formatDateTime(Date(timeIntervalSince1970: postedAt))).font(.mono(12.5))
                }
            }
            GridRow {
                Text(t("detail.savedAt")).foregroundStyle(.muted)
                Text(parseISODate(post.savedAt).map(formatDateTime) ?? post.savedAt).font(.mono(12.5))
            }
        }
        .font(.plex(12.5))
    }

    private var folderPicker: some View {
        Menu {
            Button(t("nav.unsorted")) { move(nil) }
            ForEach(app.sidebar.categories) { c in
                Section(c.name) {
                    ForEach(c.folders) { f in Button("\(c.name) / \(f.name)") { move(f.id) } }
                }
            }
            if !app.sidebar.uncategorized.isEmpty {
                Section(t("nav.uncategorized")) {
                    ForEach(app.sidebar.uncategorized) { f in Button(f.name) { move(f.id) } }
                }
            }
        } label: {
            HStack {
                Text(app.sidebar.folderLabel(post.folderId) ?? t("nav.unsorted")).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(.muted)
            }
            .foregroundStyle(.text)
            .inputBox()
        }
        .disabled(busy)
    }

    private func videoInfo(_ video: VideoView) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let url = URL(string: video.channel.url) {
                    Link(video.channel.name, destination: url).font(.plex(14, .semibold)).foregroundStyle(.text).lineLimit(1)
                }
                Spacer()
                if let url = URL(string: video.url) { externalLink(t("detail.openOnYoutube"), url) }
            }
            Text(video.title).lineSpacing(5)
        }
    }

    private func pageInfo(_ page: PageView) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SiteIcon(path: page.icon)
                VStack(alignment: .leading, spacing: 0) {
                    Text(page.siteName ?? page.host).font(.plex(14, .semibold)).lineLimit(1)
                    if page.siteName != nil { Text(page.host).font(.plex(12.5)).foregroundStyle(.muted).lineLimit(1) }
                }
                Spacer()
                if let url = URL(string: page.url) { externalLink(t("detail.openPage"), url) }
            }
            Text(page.title).font(.plex(14, .semibold)).lineSpacing(5)
            if let description = page.description { Text(description).foregroundStyle(.muted).lineSpacing(5) }
        }
    }

    private func move(_ folderID: Int?) {
        run {
            try await API.move(post.id, to: folderID)
            try await app.gallery.loadPost(post.id)
            await app.gallery.refresh()
        }
    }

    private func setTags(_ names: [String]) {
        run {
            let tags = try await API.setTags(post.id, names)
            app.gallery.posts[post.id]?.tags = tags
            await app.refreshTags()
        }
    }

    private func delete() {
        run {
            try await API.delete(post.id)
            app.gallery.removePost(post.id)
            onDeleted()
            await app.gallery.refresh()
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            do {
                try await work()
                error = nil
            } catch {
                self.error = errorMessage(error)
            }
            busy = false
        }
    }
}

func externalLink(_ label: String, _ url: URL) -> some View {
    Link(destination: url) {
        HStack(spacing: 4) {
            Text(label)
            Image(systemName: "arrow.up.right.square").font(.system(size: 12))
        }
        .font(.plex(12.5))
        .lineLimit(1)
        .fixedSize()
    }
}

private struct SiteIcon: View {
    let path: String?

    var body: some View {
        Group {
            if let path {
                RemoteImage(path: path, contentMode: .fit, maxPixel: 120).padding(4).background(.white)
            } else {
                Image(systemName: "link").foregroundStyle(.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(.raised)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(.rect(cornerRadius: 8))
    }
}

struct Avatar: View {
    let path: String?
    var size: CGFloat = 40

    var body: some View {
        RemoteImage(path: path, maxPixel: size * 3)
            .frame(width: size, height: size)
            .background(.raised)
            .clipShape(.circle)
    }
}

struct StatusContent: View {
    let status: StatusView
    var nested = false
    var openLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: nested ? 8 : 14) {
            HStack(spacing: nested ? 8 : 12) {
                Avatar(path: status.author.avatar, size: nested ? 24 : 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(status.author.name).font(.plex(nested ? 13 : 14, .semibold)).lineLimit(1)
                    Text("@\(status.author.screenName)").font(.plex(12.5)).foregroundStyle(.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if !nested, let url = URL(string: status.url) { externalLink(openLabel ?? t("detail.openOnX"), url) }
            }
            if !status.text.isEmpty {
                Text(status.text).font(.plex(nested ? 13 : 14)).lineSpacing(5).textSelection(.enabled)
            }
            if let translation = status.translation, !translation.text.isEmpty, status.lang != "ja" {
                box(t("detail.translation"), translation.text)
            }
            if let article = status.article { articleView(article) }
            if nested && !status.media.isEmpty {
                HStack(spacing: 4) {
                    ForEach(status.media, id: \.src) { m in
                        RemoteImage(path: m.thumbnail ?? m.src, maxPixel: 200).frame(width: 64, height: 64).clipShape(.rect(cornerRadius: 4))
                    }
                }
            }
            if let quote = status.quote { quoteView(quote) }
            if let card = status.card, let url = URL(string: card.url) { cardView(card, url) }
            if let choices = status.poll?.choices { pollView(choices, total: status.poll?.totalVotes) }
            if let note = status.communityNote { box(t("detail.note"), note.text) }
            if !nested { stats }
        }
    }

    private func box(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.plex(12.5)).foregroundStyle(.muted)
            Text(text).lineSpacing(5).textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.raised, in: .rect(cornerRadius: 8))
    }

    private func articleView(_ article: StatusView.Article) -> some View {
        let blocks = (article.content.blocks ?? []).compactMap(\.text).filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            Text(t("detail.article")).font(.plex(12.5)).foregroundStyle(.muted)
            if let title = article.content.title { Text(title).font(.plex(16, .semibold)) }
            if blocks.isEmpty, let preview = article.content.previewText {
                Text(preview).lineSpacing(5)
            }
            ForEach(blocks.indices, id: \.self) { Text(blocks[$0]).lineSpacing(5) }
            ForEach(article.localUrls.values.sorted(), id: \.self) { src in
                RemoteImage(path: src, contentMode: .fit, maxPixel: 1200).clipShape(.rect(cornerRadius: 6))
            }
        }
    }

    private func quoteView(_ quote: StatusView.Quote) -> some View {
        Group {
            if quote.available, let status = quote.status?.value {
                StatusContent(status: status, nested: true)
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.line))
            } else {
                Label(t("detail.quoteUnavailable") + (quote.message.map { "（\($0)）" } ?? ""), systemImage: "info.circle")
                    .labelStyle(TightLabelStyle())
                    .font(.plex(12.5))
                    .foregroundStyle(.muted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
    }

    private func cardView(_ card: StatusView.Card, _ url: URL) -> some View {
        Link(destination: url) {
            VStack(alignment: .leading, spacing: 0) {
                if let image = card.image {
                    RemoteImage(path: image, maxPixel: 1000).frame(maxWidth: .infinity).frame(height: 160).clipped()
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let domain = card.domain { Text(domain).font(.plex(12.5)).foregroundStyle(.muted) }
                    if let title = card.title { Text(title).font(.plex(13)).foregroundStyle(.text).multilineTextAlignment(.leading) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.line))
        }
    }

    private func pollView(_ choices: [StatusView.Poll.Choice], total: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(choices, id: \.label) { c in
                HStack {
                    Text(c.label)
                    Spacer()
                    Text("\(c.percentage.formatted())%").font(.mono(13))
                }
                .font(.plex(13))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(alignment: .leading) {
                    GeometryReader { geo in Color.selected.frame(width: geo.size.width * c.percentage / 100) }
                }
                .clipShape(.rect(cornerRadius: 6))
            }
            if let total { Text(t("detail.votes", ["count": formatCount(total)])).font(.plex(12.5)).foregroundStyle(.muted) }
        }
        .accessibilityLabel(t("detail.poll"))
    }

    private var stats: some View {
        let values: [(String, Int?)] = [
            ("replies", status.stats.replies), ("reposts", status.stats.reposts), ("quotes", status.stats.quotes),
            ("likes", status.stats.likes), ("views", status.stats.views), ("bookmarks", status.stats.bookmarks),
        ]
        return FlowLayout(spacing: 6) {
            ForEach(values, id: \.0) { key, value in
                if let value {
                    Text("\(Text(t("detail.\(key)")).foregroundStyle(.muted)) \(Text(formatCount(value)).font(.mono(12.5, .medium)))")
                        .padding(.trailing, 10)
                }
            }
        }
        .font(.plex(12.5))
    }
}

struct TagInput: View {
    @Environment(AppModel.self) private var app
    let value: [TagRef]
    var busy = false
    let onChange: ([String]) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let key = normalizeTagKey(text)
        let taken = Set(value.map { normalizeTagKey($0.name) })
        let matches = key.isEmpty ? [] : Array(app.tags.filter { normalizeTagKey($0.name).contains(key) && !taken.contains(normalizeTagKey($0.name)) }.prefix(6))
        let exact = app.tags.contains { normalizeTagKey($0.name) == key } || taken.contains(key)
        let newName = text.trimmingCharacters(in: .whitespaces).replacing(/^#+/, with: "")

        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 6) {
                ForEach(value) { tag in
                    HStack(spacing: 6) {
                        if let color = Color(css: tag.color) { Circle().fill(color).frame(width: 8, height: 8) }
                        Text(tag.name)
                        Button {
                            onChange(value.filter { $0.id != tag.id }.map(\.name))
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.muted).frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                        .accessibilityLabel(t("tags.remove", ["name": tag.name]))
                    }
                    .font(.plex(12.5))
                    .padding(.leading, 10)
                    .padding(.trailing, 4)
                    .frame(height: 28)
                    .background(.selected, in: .capsule)
                }
                TextField("", text: $text, prompt: Text(value.isEmpty ? t("tags.add") : "").foregroundStyle(.muted))
                    .font(.plex(16))
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { add(matches.first?.name ?? newName, taken: taken) }
                    .frame(minWidth: 80, minHeight: 28)
                    .fixedSize()
                    .accessibilityLabel(t("tags.add"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(.raised, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? .accent : .line))
            .contentShape(.rect)
            .onTapGesture { focused = true }

            if !matches.isEmpty || (!key.isEmpty && !exact) {
                VStack(spacing: 0) {
                    ForEach(matches) { tag in
                        option { add(tag.name, taken: taken) } label: {
                            Text(tag.name)
                            Spacer()
                            Text("\(tag.count)").font(.mono(12.5)).foregroundStyle(.muted)
                        }
                    }
                    if !key.isEmpty && !exact {
                        option { add(newName, taken: taken) } label: {
                            Text(t("tags.create", ["name": newName])).foregroundStyle(.accentText)
                            Spacer()
                        }
                    }
                }
                .padding(4)
                .background(.raised, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.line))
                .accessibilityLabel(t("tags.suggestions"))
            }
        }
    }

    private func option(action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            HStack { label() }
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func add(_ name: String, taken: Set<String>) {
        let key = normalizeTagKey(name)
        guard !key.isEmpty, !taken.contains(key) else { return }
        onChange(value.map(\.name) + [name])
        text = ""
    }
}
