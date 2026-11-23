import SwiftUI

struct LoginGateView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("OLKMLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .opacity(0.95)

                Text("MAPO")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Text("MOUSTACHE 工作室 官方游戏平台")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 8)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        auth.login()
                    } label: {
                        HStack(spacing: 10) {
                            if auth.isWorking { ProgressView().tint(.white) }
                            Text(auth.isWorking ? "正在登录…" : "使用 OLKM 登录")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.19, green: 0.78, blue: 0.43))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(auth.isWorking)

                    if let err = auth.errorText {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    Text("登录后会读取你的 OLKM 账号资料，用于同步游戏库与游玩记录")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 46)
            }
        }
        .sheet(item: Binding(
            get: { auth.authSheetURL.map { AuthSheetURL(url: $0) } },
            set: { if $0 == nil { auth.authSheetURL = nil } }
        )) { item in
            NavigationStack {
                OLKMAuthWebView(url: item.url) { url in
                    auth.handleCallback(url)
                } onBridge: { url in
                    auth.handleBridge(url: url)
                }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("OLKM 授权登录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { auth.authSheetURL = nil }
                    }
                }
            }
        }
    }
}

private struct AuthSheetURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
