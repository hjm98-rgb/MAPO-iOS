import SwiftUI

final class PlaytimeStore {
    static let shared = PlaytimeStore()
    private let key = "mapo.playtime"

    func seconds(for id: String) -> Int {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int])?[id] ?? 0
    }

    func add(_ delta: Int, for id: String) {
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        all[id] = (all[id] ?? 0) + delta
        UserDefaults.standard.set(all, forKey: key)
    }

    func unlockedConsole(for id: String) -> Bool { seconds(for: id) >= 600 }
}

struct GameDetailView: View {
    let game: GameInfo
    @Environment(\.dismiss) private var dismiss

    @State private var launching = false
    @State private var progress = 0.0
    @State private var rocketY: CGFloat = 260
    @State private var showPlayer = false
    @State private var stageText = "正在准备运行时"

    private let stages = ["正在校验游戏资源", "正在初始化渲染层", "正在载入关卡数据", "正在连接 MAPO 服务", "准备就绪"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [game.accent.opacity(0.9), .black], startPoint: .topTrailing, endPoint: .bottomLeading)
                            .frame(height: 220)
                        Text(game.badge.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [game.accent, .black], startPoint: .top, endPoint: .bottom))
                            Text(game.iconLetter)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.name)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(game.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("已游玩 \(PlaytimeStore.shared.seconds(for: game.id) / 60) 分钟")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        Spacer()
                    }

                    Button {
                        beginLaunch()
                    } label: {
                        Text(launching ? "加载中…" : "启动")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(red: 0.19, green: 0.78, blue: 0.43))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(launching)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("评论").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                        Text("还没有人评论")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .opacity(launching ? 0 : 1)

            if launching { loadingLayer }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) {
            GamePlayerView(game: game)
        }
    }

    private var loadingLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(red: 0.19, green: 0.78, blue: 0.43))
                    .rotationEffect(.degrees(-42))
                    .offset(y: rocketY)
                    .shadow(color: Color(red: 0.19, green: 0.78, blue: 0.43).opacity(0.6), radius: 18)
                Spacer()
                VStack(spacing: 12) {
                    Text(stageText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    ProgressView(value: progress)
                        .tint(Color(red: 0.19, green: 0.78, blue: 0.43))
                        .frame(width: 240)
                }
                Spacer().frame(height: 80)
            }
        }
        .transition(.opacity)
    }

    private func beginLaunch() {
        launching = true
        progress = 0
        rocketY = 260
        var step = 0
        let tick = Timer.scheduledTimer(withTimeInterval: 0.42, repeats: true) { t in
            step += 1
            if step < stages.count { stageText = stages[step] }
            withAnimation(.linear(duration: 0.42)) {
                progress = min(1.0, progress + 0.22)
                rocketY -= 26
            }
            if progress >= 1.0 {
                t.invalidate()
                stageText = "加载完成"
                withAnimation(.easeIn(duration: 0.7)) { rocketY -= 420 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    launching = false
                    showPlayer = true
                }
            }
        }
        RunLoop.main.add(tick, forMode: .common)
    }
}
