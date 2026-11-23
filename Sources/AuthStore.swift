import Foundation
import AuthenticationServices
import SwiftUI

/// OLKM 账号中心接入配置。发布后把 baseURL 换成正式域名即可。
enum OLKMConfig {
    static let baseURL = URL(string: "https://olkm.example.com")!
    static let clientId = "mapo-ios"
    static let callbackScheme = "mapo"
    static var authorizeURL: URL { baseURL.appendingPathComponent("oauth/authorize") }
    static var tokenURL: URL { baseURL.appendingPathComponent("api/oauth/token") }
    static var userinfoURL: URL { baseURL.appendingPathComponent("api/oauth/userinfo") }
}

@MainActor
final class AuthStore: NSObject, ObservableObject {
    @Published var profile: PlayerProfile?
    @Published var isWorking = false
    @Published var errorText: String?

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
        isWorking = true
        var comps = URLComponents(url: OLKMConfig.authorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "client_id", value: OLKMConfig.clientId),
            .init(name: "redirect_uri", value: "\(OLKMConfig.callbackScheme)://oauth"),
            .init(name: "response_type", value: "code"),
            .init(name: "state", value: UUID().uuidString)
        ]
        let session = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: OLKMConfig.callbackScheme) { [weak self] callback, error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.fail(error.localizedDescription); return }
                guard let callback,
                      let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value
                else { self.fail("没有拿到授权码"); return }
                await self.exchange(code: code)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        if !session.start() { fail("无法打开登录页") }
    }

    private func exchange(code: String) async {
        var req = URLRequest(url: OLKMConfig.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": OLKMConfig.clientId,
            "code": code,
            "redirect_uri": "\(OLKMConfig.callbackScheme)://oauth"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String
            else { fail("换令牌失败（\(httpCode(resp))）"); return }
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
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let user = json["user"] as? [String: Any]
            else { fail("拿不到账号信息"); return }
            let nickname = (user["nickname"] as? String) ?? (user["username"] as? String) ?? "玩家"
            let username = (user["username"] as? String) ?? nickname
            var p = PlayerProfile(nickname: nickname, username: username, registeredAt: Date())
            if let iso = user["created_at"] as? String, let d = ISO8601DateFormatter().date(from: iso) { p.registeredAt = d }
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
    }

    private func httpCode(_ resp: URLResponse?) -> Int { (resp as? HTTPURLResponse)?.statusCode ?? -1 }
}

extension AuthStore: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
