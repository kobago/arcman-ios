import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("theme") private var theme: Theme = .system
    @State private var settings: Settings?
    @State private var base = ""
    @State private var saved = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                card(t("settings.view")) {
                    HStack {
                        Text(t("settings.theme"))
                        Spacer()
                        Segmented(value: $theme, options: [(.system, t("settings.theme.system")), (.light, t("settings.theme.light")), (.dark, t("settings.theme.dark"))])
                    }
                    note(t("settings.localOnly"))
                }

                card(t("settings.fetch")) {
                    Text(t("settings.apiBase"))
                    HStack(spacing: 8) {
                        TextField("", text: $base)
                            .font(.mono(16))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .inputBox()
                            .onChange(of: base) { saved = false }
                        Button(t("common.save")) {
                            Task {
                                do {
                                    try await API.saveSettings(fxtwitterBaseURL: base)
                                    settings = try await API.settings()
                                    saved = true
                                    error = nil
                                } catch {
                                    self.error = errorMessage(error)
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    if saved { Text(t("settings.saved")).font(.plex(12.5)) }
                    if let error { ErrorText(error) }
                    HStack(spacing: 8) {
                        if let source = settings?.fxtwitterBaseUrl.source { ChipStatic(label: t("settings.source.\(source)"), icon: "info.circle") }
                    }
                    note(t("settings.apiBaseHint"))
                }

                card(t("settings.server")) {
                    Text(Server.baseURL?.absoluteString ?? "").font(.mono(13)).textSelection(.enabled)
                }

                card(t("settings.login")) {
                    FlowLayout(spacing: 8) {
                        Button(t("settings.logout")) { logout(all: false) }.buttonStyle(OutlineButtonStyle())
                        Button(t("settings.logoutAll")) { logout(all: true) }.buttonStyle(OutlineButtonStyle(danger: true))
                    }
                    note(t("settings.passwordHint"))
                }
            }
            .padding(16)
        }
        .background(.bg)
        .navigationTitle(t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            settings = try? await API.settings()
            base = settings?.fxtwitterBaseUrl.value ?? ""
            saved = false
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.plex(15, .semibold))
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.panel, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.line))
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.plex(12.5)).foregroundStyle(.muted)
    }

    private func logout(all: Bool) {
        Task {
            try? await API.logout(all: all)
            Server.clearCookies()
            app.loggedIn = false
        }
    }
}
