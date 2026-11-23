import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var query = ""
    @State private var bannerIndex = 0
    @State private var selected: GameInfo?
    @State private var showSettings = false

    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private var filtered: [GameInfo] {
        query.isEmpty ? Catalog.games : Catalog.games.filter {
            $0.name.contains(query) || $0.subtitle.contains(query) || $0.badge.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        searchBar
                        bannerCarousel
                        sectionTitle("最近游玩")
                        recentRow
                        sectionTitle("全部游戏")
                        grid
                        footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selected != nil },
                set: { if !$0 { selected = nil } }
            )) {
                if let game = selected { GameDetailView(game: game) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                bannerIndex = (bannerIndex + 1) % Catalog.games.count
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("OLKMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
            Text("MAPO")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
            Spacer()
            Button {
                showSettings = true
            } label: {
                ZStack {
                    Circle().fill(Color(red: 0.19, green: 0.78, blue: 0.43).opacity(0.18))
                    Text(auth.profile?.avatarText ?? "?")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.19, green: 0.78, blue: 0.43))
                }
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
        .padding(.top, 6)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.4))
            TextField("搜索游戏", text: $query)
                .foregroundStyle(.white)
                .tint(Color(red: 0.19, green: 0.78, blue: 0.43))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var bannerCarousel: some View {
        TabView(selection: $bannerIndex) {
            ForEach(Array(Catalog.games.enumerated()), id: \.offset) { idx, game in
                Button { selected = game } label: {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [game.accent.opacity(0.85), .black],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.badge.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(game.name)
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(game.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 2)
                    .padding(.bottom, 6)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 190)
    }

    private var recentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Catalog.games.prefix(3)) { game in
                    Button { selected = game } label: {
                        gameIcon(game, size: 74)
                    }
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(filtered) { game in
                Button { selected = game } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            LinearGradient(colors: [game.accent.opacity(0.75), .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 96)
                            Text(game.iconLetter)
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(12)
                        }
                        Text(game.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(game.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    .padding(.bottom, 10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 4)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            Text("© 2026 MOUSTACHE 工作室 · MAPO 内置游戏库")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 8)
        }
        .padding(.top, 10)
    }

    private func gameIcon(_ game: GameInfo, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [game.accent, .black], startPoint: .top, endPoint: .bottom))
            Text(game.iconLetter)
                .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color(red: 0.19, green: 0.78, blue: 0.43).opacity(0.18))
                                Text(auth.profile?.avatarText ?? "?")
                                    .font(.system(size: 26, weight: .heavy))
                                    .foregroundStyle(Color(red: 0.19, green: 0.78, blue: 0.43))
                            }
                            .frame(width: 76, height: 76)
                            Text(auth.profile?.nickname ?? "未登录")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                            Text("@\(auth.profile?.username ?? "-")")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.top, 18)

                        infoRow("注册时间", dateText)
                        infoRow("账号权限", "官方应用 · 已授权")
                        Link(destination: URL(string: "https://olkm.example.com")!) {
                            HStack {
                                Text("OLKM 官网")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            auth.logout()
                            dismiss()
                        } label: {
                            Text("退出账号")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private var dateText: String {
        guard let d = auth.profile?.registeredAt else { return "-" }
        let f = DateFormatter()
        f.dateFormat = "M 月 d 日"
        return f.string(from: d)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value).foregroundStyle(.white)
        }
        .font(.system(size: 14))
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
