import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var app
    @State private var server = Server.baseURL?.absoluteString ?? ""
    @State private var password = ""
    @State private var message: String?
    @State private var busy = false
    @FocusState private var focus: Field?

    enum Field { case server, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Monogram(size: 88, ground: .bg, metal: true)
                    Wordmark(height: 30, metal: true)
                }
                .accessibilityElement()
                .accessibilityLabel("ARCMAN")

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(t("login.server"))
                    TextField("", text: $server, prompt: Text(verbatim: "http://100.64.0.1:3000").foregroundStyle(.muted))
                        .font(.mono(16))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .server)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                        .inputBox(focused: focus == .server, large: true)
                    FieldLabel(t("login.password"))
                    SecureField("", text: $password)
                        .font(.plex(16))
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .inputBox(focused: focus == .password, invalid: message != nil, large: true)
                    if let message { ErrorText(message) }
                    Button(action: submit) { Text(t("login.submit")).frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle(large: true))
                        .disabled(busy)
                        .opacity(busy ? 0.6 : 1)
                        .padding(.top, 6)
                }
                .frame(maxWidth: 360)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.bg)
        .onAppear { focus = server.isEmpty ? .server : .password }
    }

    private func submit() {
        guard !busy, !password.isEmpty else { return }
        guard let url = Server.parse(server) else {
            message = t("login.serverInvalid")
            return
        }
        busy = true
        message = nil
        Task {
            defer { busy = false }
            if url != Server.baseURL { Server.clearCookies() }
            Server.baseURL = url
            server = url.absoluteString
            do {
                try await API.login(password)
                password = ""
                app.didLogIn()
            } catch let error as APIError where error.status == 401 {
                message = t("login.wrong")
            } catch let error as APIError where error.status == 429 {
                message = t("login.locked")
            } catch {
                message = errorMessage(error)
            }
        }
    }
}
