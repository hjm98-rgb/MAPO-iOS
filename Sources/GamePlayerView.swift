import SwiftUI
import WebKit
import UIKit

final class WebGameController: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var fps: Int = 0
    @Published var loaded = false
    let webView: WKWebView

    private var poll: Timer?
    private var secondsCounter = 0

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
    }

    func load(file: String) {
        guard let url = Bundle.main.url(forResource: file, withExtension: "html", subdirectory: "Games")
                ?? Bundle.main.url(forResource: file, withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        startMetering()
    }

    private func startMetering() {
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.webView.evaluateJavaScript("window.__mapoFps || 0") { value, _ in
                if let v = value as? NSNumber { self.fps = v.intValue }
            }
            self.secondsCounter += 1
        }
    }

    func stopMetering() {
        poll?.invalidate()
        poll = nil
    }
}

struct GamePlayerView: View {
    let game: GameInfo
    @Environment(\.dismiss) private var dismiss

    @StateObject private var controller = WebGameController()
    @State private var showConsole = false
    @State private var playedSeconds = 0
    @State private var fpsCap = 60

    private var consoleUnlocked: Bool {
        PlaytimeStore.shared.seconds(for: game.id) + playedSeconds >= 600
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameWebView(webView: controller.webView)
                .ignoresSafeArea()

            Button {
                if consoleUnlocked { showConsole = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: consoleUnlocked ? "gamecontroller.fill" : "lock.fill")
                    Text(consoleUnlocked ? "控制台" : "控制台 · 玩满 10 分钟解锁")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.55), in: Capsule())
                .foregroundStyle(consoleUnlocked ? Color(red: 0.19, green: 0.78, blue: 0.43) : .white.opacity(0.55))
            }
            .padding(.leading, 14)
            .padding(.top, 10)

            VStack {
                Spacer()
                Text("正在运行 · \(game.name)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            controller.load(file: game.htmlFile)
            startClock()
        }
        .onDisappear {
            controller.stopMetering()
            PlaytimeStore.shared.add(playedSeconds, for: game.id)
        }
        .sheet(isPresented: $showConsole) {
            ConsolePanel(game: game, fps: controller.fps, fpsCap: $fpsCap, playedSeconds: playedSeconds) {
                showConsole = false
                dismiss()
            }
            .presentationDetents([.medium])
        }
    }

    private func startClock() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            playedSeconds += 1
        }
    }
}

struct GameWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ConsolePanel: View {
    let game: GameInfo
    let fps: Int
    @Binding var fpsCap: Int
    let playedSeconds: Int
    var onExit: () -> Void

    private var deviceName: String { UIDevice.current.model }
    private var systemVersion: String { UIDevice.current.systemVersion }
    private var maxHz: Int { UIScreen.main.maximumFramesPerSecond }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack {
                        infoCell("设备", deviceName)
                        infoCell("系统", "iOS " + systemVersion)
                    }
                    HStack {
                        infoCell("实时帧率", "\(fps) FPS")
                        infoCell("屏幕上限", "\(maxHz) Hz")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("最高帧率").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                        HStack(spacing: 10) {
                            ForEach([30, 60, maxHz], id: \.self) { hz in
                                Button {
                                    fpsCap = hz
                                    UserDefaults.standard.set(hz, forKey: "mapo.fpsCap")
                                } label: {
                                    Text("\(hz)")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(fpsCap == hz ? Color(red: 0.19, green: 0.78, blue: 0.43) : Color.white.opacity(0.07),
                                                    in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(fpsCap == hz ? .black : .white)
                                }
                            }
                        }
                    }

                    Text("本次已游玩 \(playedSeconds / 60) 分 \(playedSeconds % 60) 秒")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    Spacer()

                    Button(action: onExit) {
                        Text("退出游戏")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .navigationTitle("控制台 · \(game.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { onExit() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func infoCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
