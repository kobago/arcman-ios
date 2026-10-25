import Foundation

enum Lang {
    static let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? true
    static let locale = Locale(identifier: isJapanese ? "ja_JP" : "en_US")
}

func t(_ key: String, _ vars: [String: Any] = [:]) -> String {
    var text = (Lang.isJapanese ? Strings.ja : Strings.en)[key] ?? Strings.ja[key] ?? key
    for (name, value) in vars {
        text = text.replacingOccurrences(of: "{\(name)}", with: "\(value)")
    }
    return text
}

func errorMessage(_ error: Error) -> String {
    if let error = error as? APIError, Strings.ja["error.\(error.code)"] != nil { return t("error.\(error.code)") }
    if error is URLError { return t("login.unreachable") }
    return t("error.generic")
}

func formatCount(_ n: Int) -> String {
    n.formatted(.number.locale(Lang.locale))
}

func formatDuration(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600, m = total % 3600 / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

func formatDateTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.string(from: date)
}

func parseISODate(_ text: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: text) ?? ISO8601DateFormatter().date(from: text)
}

func normalizeTagKey(_ name: String) -> String {
    var key = name.precomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    while key.hasPrefix("#") { key.removeFirst() }
    return key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

func hostOf(_ url: String) -> String {
    guard let host = URL(string: url)?.host() else { return url }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
}
