import SwiftUI

struct GameInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let badge: String
    let iconLetter: String
    let accent: Color
    let htmlFile: String
}

enum Catalog {
    static let games: [GameInfo] = [
        GameInfo(id: "snake", name: "贪吃墙", subtitle: "像素节奏 · 越吃越快", badge: "像素", iconLetter: "S", accent: Color(red: 0.19, green: 0.78, blue: 0.43), htmlFile: "snake"),
        GameInfo(id: "breakout", name: "砖块前线", subtitle: "挡板与砖墙的攻防", badge: "街机", iconLetter: "B", accent: Color(red: 0.25, green: 0.55, blue: 0.98), htmlFile: "breakout"),
        GameInfo(id: "tap", name: "点点冲刺", subtitle: "十秒内点到最多的方块", badge: "休闲", iconLetter: "T", accent: Color(red: 0.98, green: 0.66, blue: 0.18), htmlFile: "tap"),
        GameInfo(id: "runner", name: "跑者协议", subtitle: "躲开一切，别停下", badge: "跑酷", iconLetter: "R", accent: Color(red: 0.85, green: 0.28, blue: 0.45), htmlFile: "runner"),
        GameInfo(id: "memory", name: "记忆矩阵", subtitle: "翻牌配对，考验记性", badge: "解谜", iconLetter: "M", accent: Color(red: 0.55, green: 0.42, blue: 0.95), htmlFile: "memory"),
    ]
}

struct PlayerProfile: Codable {
    var nickname: String
    var username: String
    var registeredAt: Date
    var avatarText: String { String(nickname.prefix(1)).uppercased() }
}
