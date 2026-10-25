import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let host = UIHostingController(rootView: ShareView(items: items) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct ShareView: View {
    enum Phase {
        case saving, saved, duplicate, failed(String)
    }

    let items: [NSExtensionItem]
    let close: () -> Void
    @State private var url: String?
    @State private var phase = Phase.saving

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(t("share.title")).font(.plex(15, .semibold))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").foregroundStyle(.muted).frame(width: 44, height: 44)
                }
                .accessibilityLabel(t("common.close"))
            }
            if let url {
                Text(url.replacing(/^https?:\/\//, with: ""))
                    .font(.mono(12))
                    .foregroundStyle(.muted)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            HStack(spacing: 10) {
                mark.frame(width: 22, height: 22)
                Text(message).foregroundStyle(isFailure ? .danger : .text)
            }
            .font(.plex(14))
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .background(.panel, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.line))
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(Color.scrim.ignoresSafeArea())
        .foregroundStyle(.text)
        .task { await run() }
    }

    private var isFailure: Bool {
        if case .failed = phase { return true }
        return false
    }

    private var message: String {
        switch phase {
        case .saving: t("save.fetching")
        case .saved: t("save.downloaded")
        case .duplicate: t("save.duplicate")
        case .failed(let text): text
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch phase {
        case .saving: ProgressView().tint(.accent)
        case .saved: circle("✓", .success)
        case .duplicate: circle("=", .muted)
        case .failed: circle("!", .danger)
        }
    }

    private func circle(_ symbol: String, _ color: Color) -> some View {
        Text(symbol).font(.plex(12, .semibold)).foregroundStyle(Color(hex: 0x0e0f11)).frame(width: 20, height: 20).background(color, in: .circle)
    }

    private func run() async {
        guard let url = await sharedURL() else {
            phase = .failed(t("share.noURL"))
            return
        }
        self.url = url
        guard Server.baseURL != nil else {
            phase = .failed(t("share.loginRequired"))
            return
        }
        do {
            let result = try await API.save([url], folderID: nil).first
            switch result?.outcome {
            case .created?:
                phase = .saved
                try? await Task.sleep(for: .seconds(1))
                close()
            case .duplicate?: phase = .duplicate
            case .invalidUrl?: phase = .failed(t("save.invalid_url"))
            case .unavailable?: phase = .failed(t(result?.reason == "login_required" ? "save.loginRequired" : "save.unavailable"))
            case nil: phase = .failed(t("error.generic"))
            }
        } catch let error as APIError where error.status == 401 {
            phase = .failed(t("share.loginRequired"))
        } catch {
            phase = .failed(errorMessage(error))
        }
    }

    private func sharedURL() async -> String? {
        let providers = items.flatMap { $0.attachments ?? [] }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !url.isFileURL {
                return url.absoluteString
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String, let url = firstURL(in: text) {
                return url
            }
        }
        return items.compactMap { $0.attributedContentText?.string }.lazy.compactMap(firstURL).first
    }
}

func firstURL(in text: String) -> String? {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let range = NSRange(text.startIndex..., in: text)
    return detector?.matches(in: text, range: range)
        .compactMap(\.url)
        .first { ["http", "https"].contains($0.scheme?.lowercased()) }?
        .absoluteString
}
