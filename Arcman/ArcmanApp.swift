import AVFoundation
import SwiftUI

@main
struct ArcmanApp: App {
    @State private var app = AppModel()
    @AppStorage("theme") private var theme: Theme = .system

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Color.bg)
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.font: UIFont.plex(17, semibold: true), .foregroundColor: UIColor(Color.text)]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .font(.plex(14))
                .foregroundStyle(.text)
                .tint(.accentText)
                .preferredColorScheme(theme.colorScheme)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            switch app.loggedIn {
            case nil: Color.bg.ignoresSafeArea()
            case false?: LoginView()
            case true?:
                NavigationStack(path: $app.path) {
                    GalleryView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .tags: TagsView()
                            case .settings: SettingsView()
                            }
                        }
                }
            }
        }
        .task { await app.checkSession() }
    }
}

enum Route: Hashable {
    case tags, settings
}

@Observable
final class AppModel {
    var loggedIn: Bool?
    var path: [Route] = []
    var sidebar = Sidebar(categories: [], uncategorized: [])
    var tags: [Tag] = []
    let gallery = GalleryModel()
    let toasts = SaveToasts()

    init() {
        API.onUnauthorized = { [weak self] in self?.loggedIn = false }
    }

    func checkSession() async {
        guard Server.baseURL != nil else {
            loggedIn = false
            return
        }
        do {
            loggedIn = try await API.session()
        } catch {
            loggedIn = !(Server.cookies.cookies ?? []).isEmpty
        }
    }

    func didLogIn() {
        path = []
        gallery.reset()
        loggedIn = true
    }

    func refreshSidebar() async {
        if let sidebar = try? await API.sidebar() { self.sidebar = sidebar }
    }

    func refreshTags() async {
        if let tags = try? await API.tags(sort: "name") { self.tags = tags }
    }
}
