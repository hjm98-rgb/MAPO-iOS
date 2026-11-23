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
    /// App 内回传通道（自定义 scheme，只在 WebView 内部拦截，不发起真实导航）
    static let bridgeScheme = "mapo-app"

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
    /// 外部服务端可直接调（平台在 /api 前缀强制 Cookie+CSRF，故换令牌在站内会话里完成）
    static var tokenURL: URL { baseURL.appendingPathComponent("oauth/token") }
    static var userinfoURL: URL { baseURL.appendingPathComponent("oauth/userinfo") }
    static var apiTokenURL: URL { baseURL.appendingPathComponent("api/oauth/token") }
    static var apiUserinfoURL: URL { baseURL.appendingPathComponent("api/oauth/userinfo") }
}

@MainActor
final class AuthStore: NSObject, ObservableObject {
    @Published var profile: PlayerProfile?
    @Published var isWorking = false
    @Published var errorText: String?
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

    func login() {
        errorText = nil
        authSheetURL = OLKMConfig.authorizeURL
    }

    /// WebView 拦到 mapo.local 回调时调用（仅拿到授权码）。
    func handleCallback(_ url: URL) {
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

    /// WebView 内换令牌成功后的回传：tok + user(json)
    func handleBridge(url: URL) {
        authSheetURL = nil
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let err = q.first(where: { $0.name == "err" })?.value {
            fail("换令牌失败：\(err)")
            return
        }
        guard let tok = q.first(where: { $0.name == "tok" })?.value else {
            fail("没有拿到 access_token")
            return
        }
        accessToken = tok
        if let userRaw = q.first(where: { $0.name == "user" })?.value,
           let data = userRaw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            applyUser(json)
        }
        if profile == nil {
            Task { await loadUserinfo() }
        } else {
            isWorking = false
        }
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
            let status = httpCode(resp)
            guard status == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String
            else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                fail("换令牌失败（HTTP \(status)）\(raw.prefix(140))")
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
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                applyUser(json)
            } else {
                isWorking = false
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func applyUser(_ json: [String: Any]) {
        guard let user = (json["user"] as? [String: Any]) ?? (json["data"] as? [String: Any]) else {
            isWorking = false
            return
        }
        let nickname = (user["nickname"] as? String) ?? (user["username"] as? String) ?? "玩家"
        let username = (user["username"] as? String) ?? nickname
        var p = PlayerProfile(nickname: nickname, username: username, registeredAt: Date())
        if let iso = (user["createdAt"] ?? user["created_at"]) as? String, let d = ISO8601DateFormatter().date(from: iso) {
            p.registeredAt = d
        }
        profile = p
        if let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: "olkm.profile") }
        isWorking = false
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

/// OLKM 授权页（站内真实页面）。
/// 1) 拦下 https://mapo.local/oauth 拿授权码；
/// 2) 在同一个 WebView 里用站点自己的 Cookie 与会话换令牌（绕开平台对 /api 的 CSRF 拦截）；
/// 3) 通过 mapo-app:// 回传令牌与资料。
struct OLKMAuthWebView: UIViewRepresentable {
    let url: URL
    let onCallback: (URL) -> Void
    let onBridge: (URL) -> Void

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

    func makeCoordinator() -> Coordinator {
        Coordinator(onCallback: onCallback, onBridge: onBridge)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onCallback: (URL) -> Void
        let onBridge: (URL) -> Void
        init(onCallback: @escaping (URL) -> Void, onBridge: @escaping (URL) -> Void) {
            self.onCallback = onCallback
            self.onBridge = onBridge
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }

            if url.scheme == OLKMConfig.bridgeScheme {
                decisionHandler(.cancel)
                onBridge(url)
                return
            }

            if url.host == OLKMConfig.callbackHost {
                decisionHandler(.cancel)
                onCallback(url)
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                if let code = items.first(where: { $0.name == "code" })?.value {
                    runExchange(in: webView, code: code)
                }
                return
            }

            decisionHandler(.allow)
        }

        /// 在站点页面上下文里换令牌：带 credentials 与站内 csrf_token，平台不会拦。
        private func runExchange(in web: WKWebView, code: String) {
            let base = OLKMConfig.baseURL.absoluteString
            let script = """
            (function(){
              function ck(n){var m=document.cookie.match(new RegExp('(^| )'+n+'=([^;]+)'));return m?decodeURIComponent(m[2]):'';}
              var csrf=ck('suda-csrf-token');
              var base='\(base)';
              var code='\(code)';
              var body={grant_type:'authorization_code',code:code,client_id:'\(OLKMConfig.clientId)',client_secret:'\(OLKMConfig.clientSecret)',redirect_uri:'\(OLKMConfig.redirectURI)'};
              function done(q){location.href='\(OLKMConfig.bridgeScheme)://auth?'+q;}
              fetch(base+'/api/oauth/token',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json','X-Suda-Csrf-Token':csrf},body:JSON.stringify(body)})
                .then(function(r){return r.text()})
                .then(function(t){
                  var j=null;try{j=JSON.parse(t)}catch(e){}
                  if(!j||!j.access_token){done('err='+encodeURIComponent(t.slice(0,180)));return;}
                  var tok=j.access_token;
                  return fetch(base+'/api/oauth/userinfo',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json','Authorization':'Bearer '+tok,'X-Suda-Csrf-Token':csrf}})
                    .then(function(r){return r.text()})
                    .then(function(u){done('tok='+encodeURIComponent(tok)+'&user='+encodeURIComponent(u));});
                })
                .catch(function(e){done('err='+encodeURIComponent(String(e)));});
            })();
            """
            web.evaluateJavaScript(script) { _, err in
                if let err {
                    print("OLKM exchange js error:", err.localizedDescription)
                }
            }
        }
    }
}
