import SwiftUI

struct SaveSheet: View {
    @Environment(AppModel.self) private var app
    let folderID: Int?
    let destination: String
    let done: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(t("save.label"))
            TextEditor(text: $text)
                .font(.mono(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .frame(height: 96)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.raised, in: .rect(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(t("save.placeholder"))
                            .font(.mono(13))
                            .foregroundStyle(.muted)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? .accent : .line))
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(t("save.destination"))
                    ChipStatic(label: destination)
                }
                .font(.plex(13))
                .foregroundStyle(.muted)
                Spacer(minLength: 0)
                Button(t("common.save"), action: submit).buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(.line).frame(height: 1) }
        .onAppear { focused = true }
    }

    private func submit() {
        let urls = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !urls.isEmpty else { return }
        app.toasts.save(urls, folderID: folderID, destination: destination, app: app)
        text = ""
        done()
    }
}

@Observable
final class SaveToasts {
    struct Toast: Identifiable {
        let id = UUID()
        let urls: [String]
        let destination: String
        var results: [SaveResult]?
        var duplicateFolders: [Int: String] = [:]
        var progress: [Int: PostProgress] = [:]
        var error: Error?

        var created: [Int] { results?.compactMap { $0.outcome == .created ? $0.postId : nil } ?? [] }
        var downloading: [Int] { created.filter { progress[$0]?.state != .done && progress[$0]?.state != .failed } }
        var downloaded: Int { created.filter { progress[$0]?.state == .done }.count }
        var settled: Bool { error != nil || (results != nil && downloading.isEmpty) }
        var clean: Bool {
            settled && error == nil && created.count == downloaded
                && results!.allSatisfy { $0.outcome == .created || $0.outcome == .duplicate }
        }
    }

    var items: [Toast] = []

    func close(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    private func update(_ id: UUID, _ change: (inout Toast) -> Void) {
        if let i = items.firstIndex(where: { $0.id == id }) { change(&items[i]) }
    }

    func save(_ urls: [String], folderID: Int?, destination: String, app: AppModel) {
        let toast = Toast(urls: urls, destination: destination)
        items.append(toast)
        Task {
            do {
                let results = try await API.save(urls, folderID: folderID)
                var folders: [Int: String] = [:]
                for r in results where r.outcome == .duplicate {
                    if let id = r.postId, let post = try? await API.post(id), let label = app.sidebar.folderLabel(post.folderId) {
                        folders[id] = label
                    }
                }
                update(toast.id) {
                    $0.results = results
                    $0.duplicateFolders = folders
                }
                await app.gallery.refresh()
                let created = results.compactMap { $0.outcome == .created ? $0.postId : nil }
                while !created.isEmpty {
                    if let progress = try? await API.progress(created) {
                        update(toast.id) { $0.progress = Dictionary(progress.map { ($0.postId, $0) }, uniquingKeysWith: { a, _ in a }) }
                        if progress.allSatisfy({ $0.state != .pending }) { break }
                    }
                    try? await Task.sleep(for: .milliseconds(700))
                }
                if !created.isEmpty { await app.gallery.refresh() }
                if items.first(where: { $0.id == toast.id })?.clean == true {
                    try? await Task.sleep(for: .seconds(5))
                    close(toast.id)
                }
            } catch {
                update(toast.id) { $0.error = error }
            }
        }
    }
}

struct SaveToastsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 10) {
            ForEach(app.toasts.items) { toast in
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.18), value: app.toasts.items.map(\.id))
    }
}

private struct ToastView: View {
    @Environment(AppModel.self) private var app
    let toast: SaveToasts.Toast

    private var head: String {
        guard toast.results != nil else {
            return toast.error.map(errorMessage) ?? t("save.saving", ["count": toast.urls.count])
        }
        if !toast.downloading.isEmpty {
            return t("save.downloading", ["done": toast.downloaded, "total": toast.created.count])
        }
        return t("save.saved", ["count": toast.created.count])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(head).font(.plex(13, .semibold)).foregroundStyle(toast.error == nil ? .text : .danger)
                Spacer()
                Button { app.toasts.close(toast.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(.muted).frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("common.close"))
            }
            HStack(spacing: 8) {
                Text(t("save.destination"))
                ChipStatic(label: toast.destination)
            }
            .font(.plex(13))
            .foregroundStyle(.muted)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let results = toast.results {
                        ForEach(results.indices, id: \.self) { i in row(results[i]) }
                    } else {
                        ForEach(toast.urls, id: \.self) { url in
                            ResultRow(url: url, mark: toast.error == nil ? .spinner : .bad, message: toast.error == nil ? t("save.fetching") : "", value: toast.error == nil ? .some(nil) : nil)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 260)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.panel, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.line))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 12)
    }

    @ViewBuilder
    private func row(_ r: SaveResult) -> some View {
        switch r.outcome {
        case .created:
            let p = r.postId.flatMap { toast.progress[$0] }
            if p?.state == .done {
                ResultRow(url: r.url, mark: .good("✓"), message: t("save.downloaded"), value: 1)
            } else if p?.state == .failed {
                ResultRow(url: r.url, mark: .bad, message: t("failure.media_download"), danger: true)
            } else if let value = p?.progress {
                ResultRow(url: r.url, mark: .spinner, message: "\(t("save.downloadingOne")) \(Int(value * 100))%", value: value)
            } else {
                ResultRow(url: r.url, mark: .spinner, message: t("save.queued"), value: 0)
            }
        case .duplicate:
            let folder = r.postId.flatMap { toast.duplicateFolders[$0] }
            ResultRow(url: r.url, mark: .same, message: folder.map { t("save.duplicateIn", ["folder": $0]) } ?? t("save.duplicate")) {
                if let id = r.postId {
                    Button(t("save.openPost")) {
                        app.toasts.close(toast.id)
                        app.gallery.opened = TileRef(postId: id, index: 0)
                    }
                    .font(.plex(13))
                    .foregroundStyle(.accentText)
                }
            }
        case .invalidUrl:
            ResultRow(url: r.url, mark: .bad, message: t("save.invalid_url"), danger: true)
        case .unavailable:
            ResultRow(url: r.url, mark: .bad, message: t(r.reason == "login_required" ? "save.loginRequired" : "save.unavailable"), danger: true)
        }
    }
}

struct ResultRow<Trailing: View>: View {
    enum Mark { case good(String), same, bad, spinner }
    let url: String
    let mark: Mark
    let message: String
    var value: Double?? = nil
    var danger = false
    @ViewBuilder var trailing: Trailing

    init(url: String, mark: Mark, message: String, value: Double?? = nil, danger: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.url = url
        self.mark = mark
        self.message = message
        self.value = value
        self.danger = danger
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            markView.frame(width: 18, height: 18).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.replacing(/^https?:\/\//, with: "")).font(.mono(12)).foregroundStyle(.muted).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 4) {
                    if !message.isEmpty { Text(message).foregroundStyle(danger ? .danger : .text) }
                    trailing
                }
                .font(.plex(13))
                if let value { ProgressBar(value: value, done: value == 1) }
            }
        }
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .good(let symbol): circle(symbol, .success)
        case .same: circle("=", .muted)
        case .bad: circle("!", .danger)
        case .spinner: Spinner(size: 16)
        }
    }

    private func circle(_ symbol: String, _ color: Color) -> some View {
        Text(symbol).font(.plex(11, .semibold)).foregroundStyle(Color(hex: 0x0e0f11)).frame(width: 18, height: 18).background(color, in: .circle)
    }
}

extension ResultRow where Trailing == EmptyView {
    init(url: String, mark: Mark, message: String, value: Double?? = nil, danger: Bool = false) {
        self.init(url: url, mark: mark, message: message, value: value, danger: danger) { EmptyView() }
    }
}

struct ProgressBar: View {
    let value: Double?
    var done = false
    @State private var slide = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.selected)
                if let value {
                    Capsule().fill(done ? .success : .accent).frame(width: geo.size.width * value)
                        .animation(.easeOut(duration: 0.3), value: value)
                } else {
                    Capsule().fill(.accent).frame(width: geo.size.width * 0.35)
                        .offset(x: slide ? geo.size.width : -geo.size.width * 0.35)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: slide)
                        .onAppear { slide = true }
                }
            }
            .clipShape(.capsule)
        }
        .frame(height: 4)
        .padding(.top, 4)
    }
}
