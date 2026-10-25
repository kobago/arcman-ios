import SwiftUI

struct Drawer: View {
    @Binding var open: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if open {
                    Color.scrim
                        .ignoresSafeArea()
                        .onTapGesture { open = false }
                        .transition(.opacity)
                    SidebarView { open = false }
                        .frame(width: min(300, geo.size.width * 0.85))
                        .transition(.move(edge: .leading))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: open)
    }
}

private struct SidebarGroup: Identifiable {
    let id: Int?
    let name: String
    let folders: [Folder]
}

private enum Prompt: Identifiable {
    case newCategory
    case newFolder(categoryID: Int?)
    case renameCategory(Int, String)
    case renameFolder(Int, String)

    var id: String {
        switch self {
        case .newCategory: "newCategory"
        case .newFolder(let c): "newFolder\(c ?? 0)"
        case .renameCategory(let id, _): "renameCategory\(id)"
        case .renameFolder(let id, _): "renameFolder\(id)"
        }
    }
}

private enum Confirm: Identifiable {
    case folder(Folder, count: Int)
    case category(Int, String)

    var id: String {
        switch self {
        case .folder(let f, _): "folder\(f.id)"
        case .category(let id, _): "category\(id)"
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("collapsed") private var collapsedRaw = ""
    @State private var prompt: Prompt?
    @State private var promptText = ""
    @State private var confirm: Confirm?
    @State private var error: String?
    let close: () -> Void

    private var collapsed: Set<String> { Set(collapsedRaw.split(separator: ",").map(String.init)) }

    private var groups: [SidebarGroup] {
        app.sidebar.categories.map { SidebarGroup(id: $0.id, name: $0.name, folders: $0.folders) }
            + [SidebarGroup(id: nil, name: t("nav.uncategorized"), folders: app.sidebar.uncategorized)]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Logo()
                Spacer()
                IconButton(systemImage: "xmark", label: t("common.close"), action: close)
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    navItem("all", t("nav.all"), icon: "square.grid.2x2")
                    navItem("unsorted", t("nav.unsorted"), icon: "list.bullet")
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                    Button {
                        open(.newCategory)
                    } label: {
                        Label(t("nav.addCategory"), systemImage: "plus")
                            .labelStyle(TightLabelStyle())
                            .font(.plex(13))
                            .foregroundStyle(.muted)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    if let error { ErrorText(error).padding(.horizontal, 10) }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            VStack(spacing: 0) {
                footItem(t("nav.tags"), icon: "tag", route: .tags)
                footItem(t("nav.settings"), icon: "gearshape", route: .settings)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .overlay(alignment: .top) { Rectangle().fill(.line).frame(height: 1) }
        }
        .background(.panel)
        .overlay(alignment: .trailing) { Rectangle().fill(.line).frame(width: 1) }
        .alert(promptTitle, isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })) {
            TextField("", text: $promptText)
            Button(t("common.cancel"), role: .cancel) {}
            Button(t("common.save"), action: submitPrompt)
        }
        .alert(confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), presenting: confirm) { c in
            Button(t("common.cancel"), role: .cancel) {}
            Button(confirmLabel(c), role: .destructive) { delete(c) }
        } message: { c in
            switch c {
            case .folder(_, let count):
                Text(t("nav.deleteFolder.body", ["count": count]) + (count > 0 ? "\n\n" + t("nav.deleteFolder.hint") : ""))
            case .category:
                Text(t("nav.deleteCategory.body"))
            }
        }
        .task { await app.refreshSidebar() }
    }

    private func navItem(_ folder: String, _ label: String, icon: String) -> some View {
        let active = app.gallery.filters.folder == folder
        return Button {
            app.gallery.filters.folder = folder
            close()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                Text(label).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.plex(14, active ? .medium : .regular))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(active ? Color.selected : .clear, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func groupSection(_ group: SidebarGroup) -> some View {
        let key = group.id.map(String.init) ?? "none"
        let isCollapsed = collapsed.contains(key)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Button { toggle(key) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        Text(group.name).tracking(0.7).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.plex(12, .semibold))
                    .foregroundStyle(.muted)
                    .frame(minHeight: 32)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t(isCollapsed ? "nav.expand" : "nav.collapse", ["name": group.name]))
                smallButton("plus", group.id == nil ? t("nav.addFolder") : t("nav.addFolderTo", ["name": group.name])) {
                    if isCollapsed { toggle(key) }
                    open(.newFolder(categoryID: group.id))
                }
                if let id = group.id {
                    Menu {
                        Button(t("common.rename"), systemImage: "pencil") { open(.renameCategory(id, group.name)) }
                        let ids = app.sidebar.categories.map(\.id)
                        if ids.first != id { Button(t("nav.moveUp"), systemImage: "arrow.up") { moveCategory(id, by: -1) } }
                        if ids.last != id { Button(t("nav.moveDown"), systemImage: "arrow.down") { moveCategory(id, by: 1) } }
                        Button(t("common.delete"), systemImage: "trash", role: .destructive) { confirm = .category(id, group.name) }
                    } label: {
                        smallIcon("ellipsis")
                    }
                    .accessibilityLabel("\(t("common.more")): \(group.name)")
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 2)
            .padding(.top, 16)
            .padding(.bottom, 4)

            if !isCollapsed {
                ForEach(group.folders) { folder in
                    folderRow(folder, in: group)
                }
            }
        }
    }

    private func folderRow(_ folder: Folder, in group: SidebarGroup) -> some View {
        let active = app.gallery.filters.folder == String(folder.id)
        return HStack(spacing: 0) {
            Button {
                app.gallery.filters.folder = String(folder.id)
                close()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder").font(.system(size: 13)).foregroundStyle(.muted)
                    Text(folder.name).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.plex(14, active ? .medium : .regular))
                .padding(.leading, 14)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Menu {
                Button(t("common.rename"), systemImage: "pencil") { open(.renameFolder(folder.id, folder.name)) }
                if group.folders.first?.id != folder.id {
                    Button(t("nav.moveUp"), systemImage: "arrow.up") { moveFolder(folder, in: group, by: -1) }
                }
                if group.folders.last?.id != folder.id {
                    Button(t("nav.moveDown"), systemImage: "arrow.down") { moveFolder(folder, in: group, by: 1) }
                }
                Menu(t("nav.moveTo")) {
                    ForEach(groups.filter { $0.id != group.id }) { target in
                        Button(target.name) {
                            run { try await API.orderFolders(categoryID: target.id, target.folders.map(\.id) + [folder.id]) }
                        }
                    }
                }
                Button(t("common.delete"), systemImage: "trash", role: .destructive) { askDelete(folder) }
            } label: {
                smallIcon("ellipsis").padding(.trailing, 4)
            }
            .accessibilityLabel("\(t("common.more")): \(folder.name)")
        }
        .background(active ? Color.selected : .clear, in: .rect(cornerRadius: 6))
    }

    private func footItem(_ label: String, icon: String, route: Route) -> some View {
        Button {
            close()
            app.path.append(route)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                Text(label)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.muted)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func smallButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { smallIcon(icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    private func smallIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.muted)
            .frame(width: 32, height: 32)
            .contentShape(.rect)
    }

    private func toggle(_ key: String) {
        var set = collapsed
        if set.contains(key) { set.remove(key) } else { set.insert(key) }
        collapsedRaw = set.sorted().joined(separator: ",")
    }

    private var promptTitle: String {
        switch prompt {
        case .newCategory: t("nav.newCategory")
        case .newFolder: t("nav.newFolder")
        case .renameCategory, .renameFolder: t("common.rename")
        case nil: ""
        }
    }

    private func open(_ p: Prompt) {
        switch p {
        case .renameCategory(_, let name), .renameFolder(_, let name): promptText = name
        default: promptText = ""
        }
        prompt = p
    }

    private func submitPrompt() {
        let name = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let p = prompt, !name.isEmpty else { return }
        run {
            switch p {
            case .newCategory: try await API.createCategory(name)
            case .newFolder(let categoryID): try await API.createFolder(name, categoryID: categoryID)
            case .renameCategory(let id, _): try await API.renameCategory(id, name)
            case .renameFolder(let id, _): try await API.renameFolder(id, name)
            }
        }
    }

    private func moveCategory(_ id: Int, by delta: Int) {
        var ids = app.sidebar.categories.map(\.id)
        guard let i = ids.firstIndex(of: id), ids.indices.contains(i + delta) else { return }
        ids.swapAt(i, i + delta)
        run { try await API.orderCategories(ids) }
    }

    private func moveFolder(_ folder: Folder, in group: SidebarGroup, by delta: Int) {
        var ids = group.folders.map(\.id)
        guard let i = ids.firstIndex(of: folder.id), ids.indices.contains(i + delta) else { return }
        ids.swapAt(i, i + delta)
        run { try await API.orderFolders(categoryID: group.id, ids) }
    }

    private func askDelete(_ folder: Folder) {
        Task {
            do {
                confirm = .folder(folder, count: try await API.folder(folder.id).postCount)
            } catch {
                self.error = errorMessage(error)
            }
        }
    }

    private var confirmTitle: String {
        switch confirm {
        case .folder(let f, _): t("nav.deleteFolder.title", ["name": f.name])
        case .category(_, let name): t("nav.deleteCategory.title", ["name": name])
        case nil: ""
        }
    }

    private func confirmLabel(_ c: Confirm) -> String {
        if case .folder(_, let count) = c, count > 0 { return t("nav.deleteFolder.confirm", ["count": count]) }
        return t("common.delete")
    }

    private func delete(_ c: Confirm) {
        run {
            switch c {
            case .folder(let folder, _):
                try await API.deleteFolder(folder.id)
                if app.gallery.filters.folder == String(folder.id) { app.gallery.filters.folder = "all" } else { await app.gallery.refresh() }
            case .category(let id, _):
                try await API.deleteCategory(id)
            }
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
            await app.refreshSidebar()
        }
    }
}
