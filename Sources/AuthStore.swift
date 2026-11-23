import Foundation
import SwiftUI
import WebKit

/// OLKM 账号中心真实接入配置（已在该站开发者后台登记应用并拿到凭证）。
enum OLKMConfig {
    static let baseURL = URL(string: "https://4khdp10614yq7.doubaoapps.com/app/app_17jfkxn3kgu")!
    static let clientId = "olkm_FXfQcbI6-FvBJhN9Ia76UsNV"
    static let clientSecret = "Nt-KIvx30dQhrF7vJgiIITsvj1Z-FkGTPQxu7QBXDacQcUiG"
    /// 登记的回调地址（只能是 http/https）。App 内不真联网，由 WebView 拦截这一跳并从 URL 取授权码。
    static let redirectURI = "https://mapo.local/oauth"
    static let callbackHost = "mapo.local"

    static var authorizeURL: URL {
        var c = URLComponents(url: baseURL.appendingPathComponent("oauth/authorize"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "profile")
        ]
        return c.url!
    }
    static var tokenURL: URL { baseURL.appendingPathComponent("api/oauth/token") }
    static var userinfoURL: URL { baseURL.appendingPathComponent("api/oauth/userinfo") }
}

@MainActor
final class AuthStore: NSObject, ObservableObject {
    @Published var profile: PlayerProfile?
    @Published var isWorking = false
    @Published var errorText: String?
    /// 非 nil 时界面弹出 OLKM 授权页
    @Published var authSheetURL: URL?

    private var accessToken: String? {
        didSet { UserDefaults.standard.set(accessToken, forKey: "olkm.accessToken") }
    }

    override init() {
        super.init()
        accessToken = UserDefaults.standard.string(forKey: "olkm.accessToken")
        if let data = UserDefaults.standard.data(forKey: "olkm.profile"),
           let p = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            profile = p
        }
    }

    var isLoggedIn: Bool { profile != nil && accessToken != nil }

    /// 打开 OLKM 授权页；已登录过就不再弹（除非换账号清空）。
    func login() {
        errorText = nil
        authSheetURL = OLKMConfig.authorizeURL
    }

    /// WebView 拦到回调地址后调用。
    func handleCallback(_ url: URL) {
        authSheetURL = nil
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let err = items.first(where: { $0.name == "error" })?.value {
            fail("授权未完成：\(err)")
            return
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            fail("没有拿到授权码")
            return
        }
        isWorking = true
        Task { await exchange(code: code) }
    }

    private func exchange(code: String) async {
        var req = URLRequest(url: OLKMConfig.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": OLKMConfig.clientId,
            "client_secret": OLKMConfig.clientSecret,
            "redirect_uri": OLKMConfig.redirectURI
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = httpCode(resp)
            guard code == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String
            else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                fail("换令牌失败（HTTP \(code)）\(raw.prefix(120))")
                return
            }
            accessToken = token
            await loadUserinfo()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func loadUserinfo() async {
        guard let token = accessToken else { return }
        var req = URLRequest(url: OLKMConfig.userinfoURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let user = (json["user"] as? [String: Any]) ?? (json["data"] as? [String: Any])
            else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                fail("拿不到账号信息（HTTP \(httpCode(resp))）\(raw.prefix(120))")
                return
            }
            let nickname = (user["nickname"] as? String) ?? (user["username"] as? String) ?? "玩家"
            let username = (user["username"] as? String) ?? nickname
            var p = PlayerProfile(nickname: nickname, username: username, registeredAt: Date())
            if let iso = user["created_at"] as? String, let d = ISO8601DateFormatter().date(from: iso) {
                p.registeredAt = d
            }
            profile = p
            if let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: "olkm.profile") }
            isWorking = false
        } catch {
            fail(error.localizedDescription)
        }
    }

    func logout() {
        accessToken = nil
        profile = nil
        UserDefaults.standard.removeObject(forKey: "olkm.profile")
    }

    private func fail(_ text: String) {
        errorText = text
        isWorking = false
        authSheetURL = nil
    }

    private func httpCode(_ resp: URLResponse?) -> Int { (resp as? HTTPURLResponse)?.statusCode ?? -1 }
}

/// OLKM 授权页（站内真实页面）。拦下 https://mapo.local/oauth 这一跳，不真发请求。
struct OLKMAuthWebView: UIViewRepresentable {
    let url: URL
    let onCallback: (URL) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCallback: onCallback) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onCallback: (URL) -> Void
        init(onCallback: @escaping (URL) -> Void) { self.onCallback = onCallback }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               url.host == OLKMConfig.callbackHost {
                decisionHandler(.cancel)
                onCallback(url)
                return
            }
            decisionHandler(.allow)
        }
    }
}
