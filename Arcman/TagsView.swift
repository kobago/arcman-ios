import SwiftUI

private let palette = ["#e06c6c", "#e6a04e", "#d9c55a", "#7cc49a", "#5fb3c7", "#7a9cf0", "#b08ae6", "#a3a9b0"]

struct TagsView: View {
    @Environment(AppModel.self) private var app
    @State private var sort = "count"
    @State private var filter = ""
    @State private var tags: [Tag] = []
    @State private var renaming: Tag?
    @State private var newName = ""
    @State private var deleting: Tag?
    @State private var error: String?

    var body: some View {
        let key = normalizeTagKey(filter)
        let visible = tags.filter { key.isEmpty || normalizeTagKey($0.name).contains(key) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(t("tags.count", ["count": tags.count])).foregroundStyle(.muted)
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.muted)
                        TextField("", text: $filter, prompt: Text(t("tags.filter")).foregroundStyle(.muted)).font(.plex(16))
                    }
                    .inputBox()
                    Segmented(value: $sort, options: [("name", t("tags.byName")), ("count", t("tags.byCount"))])
                }
                if let error { ErrorText(error) }
                if tags.isEmpty {
                    Text(t("tags.none")).foregroundStyle(.muted).frame(maxWidth: .infinity).padding(48)
                } else {
                    VStack(spacing: 0) {
                        ForEach(visible) { tag in
                            row(tag)
                            if tag.id != visible.last?.id { Rectangle().fill(.line).frame(height: 1) }
                        }
                    }
                    .background(.panel, in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.line))
                }
            }
            .padding(16)
        }
        .background(.bg)
        .navigationTitle(t("tags.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sort) { await load() }
        .alert(t("tags.newName"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { tag in
            TextField("", text: $newName)
            Button(t("common.cancel"), role: .cancel) {}
            Button(t("common.save")) { rename(tag) }
        }
        .alert(deleting.map { t("tags.deleteTitle", ["name": $0.name]) } ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { tag in
            Button(t("common.cancel"), role: .cancel) {}
            Button(t("common.delete"), role: .destructive) {
                run { try await API.deleteTag(tag.id) }
            }
        } message: { tag in
            Text(t("tags.deleteBody", ["count": tag.count]))
        }
    }

    private func row(_ tag: Tag) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(palette, id: \.self) { color in
                    Button {
                        run { try await API.setTagColor(tag.id, color) }
                    } label: {
                        Label(color, systemImage: tag.color == color ? "checkmark.circle.fill" : "circle.fill")
                    }
                    .tint(Color(css: color))
                }
                Button(t("tags.noColor")) { run { try await API.setTagColor(tag.id, nil) } }
            } label: {
                Circle()
                    .fill(Color(css: tag.color) ?? .clear)
                    .overlay(Circle().stroke(.line, lineWidth: 2))
                    .frame(width: 24, height: 24)
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel(t("tags.changeColor", ["name": tag.name]))
            Text(tag.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(tag.count)").font(.mono(14)).frame(minWidth: 40, alignment: .trailing)
            Menu {
                Button(t("tags.viewPosts"), systemImage: "square.grid.2x2") {
                    app.gallery.filters = Filters(tags: [tag.id])
                    app.path = []
                }
                Button(t("common.rename"), systemImage: "pencil") {
                    newName = tag.name
                    renaming = tag
                }
                Button(t("common.delete"), systemImage: "trash", role: .destructive) { deleting = tag }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.muted).frame(width: 36, height: 44)
            }
            .accessibilityLabel("\(t("common.more")): \(tag.name)")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 52)
    }

    private func load() async {
        if let tags = try? await API.tags(sort: sort) { self.tags = tags }
    }

    private func rename(_ tag: Tag) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                try await API.renameTag(tag.id, name)
                error = nil
            } catch let e as APIError where e.code == "tag_exists" {
                error = t("tags.exists", ["name": name])
            } catch {
                self.error = errorMessage(error)
            }
            await reloadAll()
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
                error = nil
            } catch {
                self.error = errorMessage(error)
            }
            await reloadAll()
        }
    }

    private func reloadAll() async {
        await load()
        await app.refreshTags()
        await app.gallery.refresh()
    }
}

struct Segmented<Value: Hashable>: View {
    @Binding var value: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option, label in
                Button {
                    value = option
                } label: {
                    Text(label)
                        .font(.plex(13))
                        .foregroundStyle(value == option ? .text : .muted)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(value == option ? Color.line : .clear, in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(value == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.raised, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.line))
        .fixedSize()
    }
}
