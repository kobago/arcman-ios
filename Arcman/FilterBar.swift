import SwiftUI

struct FilterBar: View {
    @Environment(AppModel.self) private var app
    @Binding var size: Int
    @State private var open: Panel?
    @State private var authors: [Author] = []

    enum Panel: Identifiable {
        case tags, period
        var id: Self { self }
    }

    private var filters: Filters { app.gallery.filters }

    private func set(_ change: (inout Filters) -> Void) {
        change(&app.gallery.filters)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters.tags, id: \.self) { id in
                    ActiveChip(label: app.tags.first { $0.id == id }?.name ?? "#\(id)") { set { $0.tags.removeAll { $0 == id } } }
                }
                if filters.from != nil || filters.to != nil {
                    ActiveChip(label: "\(filters.from.map(day) ?? "…") – \(filters.to.map(day) ?? "…")") { set { $0.from = nil; $0.to = nil } }
                }
                if let media = filters.media {
                    ActiveChip(label: mediaLabel(media)) { set { $0.media = nil } }
                }
                if !filters.author.isEmpty {
                    ActiveChip(label: "@\(filters.author)") { set { $0.author = "" } }
                }

                chip(t("filter.tags")) { open = .tags }
                    .popover(item: Binding(get: { open == .tags ? open : nil }, set: { open = $0 })) { _ in
                        TagFilterPanel().presentationCompactAdaptation(.popover)
                    }
                chip(t("filter.period")) { open = .period }
                    .popover(item: Binding(get: { open == .period ? open : nil }, set: { open = $0 })) { _ in
                        PeriodPanel { open = nil }.presentationCompactAdaptation(.popover)
                    }
                Menu {
                    Picker(t("filter.media"), selection: Binding(get: { filters.media }, set: { m in set { $0.media = m } })) {
                        Text(t("filter.media.any")).tag(Filters.Media?.none)
                        ForEach(Filters.Media.allCases, id: \.self) { Text(mediaLabel($0)).tag(Filters.Media?.some($0)) }
                    }
                } label: {
                    chipLabel(t("filter.media"))
                }
                Menu {
                    Picker(t("filter.author"), selection: Binding(get: { filters.author }, set: { a in set { $0.author = a } })) {
                        Text(t("filter.author.any")).tag("")
                        ForEach(authors, id: \.self) { a in
                            Text("\(a.name) @\(a.screenName)  \(a.count)").tag(a.screenName)
                        }
                    }
                } label: {
                    chipLabel(t("filter.author"))
                }
                .task { authors = (try? await API.authors()) ?? authors }

                Button {
                    set { $0.ascending.toggle() }
                } label: {
                    Label(t(filters.ascending ? "sort.asc" : "sort.desc"), systemImage: "arrow.up.arrow.down")
                        .labelStyle(TightLabelStyle())
                        .font(.plex(13))
                        .foregroundStyle(.muted)
                        .frame(height: 32)
                }
                .buttonStyle(.plain)

                HStack(spacing: 0) {
                    zoomButton("minus.magnifyingglass", t("zoom.out"), disabled: size == 0) { size -= 1 }
                    zoomButton("plus.magnifyingglass", t("zoom.in"), disabled: size == GallerySize.max) { size += 1 }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }

    private func day(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    private func mediaLabel(_ media: Filters.Media) -> String {
        t("filter.media.\(media.rawValue)")
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(label) }.buttonStyle(.plain)
    }

    private func chipLabel(_ label: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        }
        .font(.plex(13))
        .foregroundStyle(.text)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .overlay(Capsule().stroke(.line))
    }

    private func zoomButton(_ icon: String, _ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15)).frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.muted)
        .opacity(disabled ? 0.35 : 1)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

struct ActiveChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label).lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(.black.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("filter.remove", ["name": label]))
        }
        .font(.plex(13, .medium))
        .foregroundStyle(.accentInk)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 32)
        .background(.accent, in: .capsule)
    }
}

private struct TagFilterPanel: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""

    var body: some View {
        let key = normalizeTagKey(query)
        let visible = app.tags.filter { key.isEmpty || normalizeTagKey($0.name).contains(key) }
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $query, prompt: Text(t("filter.findTag")).foregroundStyle(.muted))
                .font(.plex(16))
                .inputBox()
            ScrollView {
                VStack(spacing: 0) {
                    if visible.isEmpty {
                        Text(t("filter.noTags")).font(.plex(12.5)).foregroundStyle(.muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(visible) { tag in
                        let on = app.gallery.filters.tags.contains(tag.id)
                        Button {
                            if on { app.gallery.filters.tags.removeAll { $0 == tag.id } } else { app.gallery.filters.tags.append(tag.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? .accent : .muted)
                                if let color = Color(css: tag.color) { Circle().fill(color).frame(width: 8, height: 8) }
                                Text(tag.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(tag.count)").font(.mono(12.5)).foregroundStyle(.muted)
                            }
                            .frame(minHeight: 36)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 280, height: 360)
        .background(.panel)
        .task { await app.refreshTags() }
    }
}

private struct PeriodPanel: View {
    @Environment(AppModel.self) private var app
    @State private var from: Date?
    @State private var to: Date?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dateRow(t("filter.from"), $from, in: Date.distantPast...(to ?? .distantFuture))
            dateRow(t("filter.to"), $to, in: (from ?? .distantPast)...Date.distantFuture)
            HStack(spacing: 8) {
                Spacer()
                Button(t("filter.clear")) { from = nil; to = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(.muted)
                    .padding(.horizontal, 12)
                Button(t("filter.apply")) {
                    app.gallery.filters.from = from
                    app.gallery.filters.to = to
                    close()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(.panel)
        .onAppear {
            from = app.gallery.filters.from
            to = app.gallery.filters.to
        }
    }

    private func dateRow(_ label: String, _ value: Binding<Date?>, in range: ClosedRange<Date>) -> some View {
        HStack {
            Text(label).font(.plex(12)).foregroundStyle(.muted)
            Spacer()
            if value.wrappedValue == nil {
                Button("—") { value.wrappedValue = .now }.buttonStyle(OutlineButtonStyle(small: true))
            } else {
                DatePicker("", selection: Binding(get: { value.wrappedValue ?? .now }, set: { value.wrappedValue = $0 }), in: range, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }
}
