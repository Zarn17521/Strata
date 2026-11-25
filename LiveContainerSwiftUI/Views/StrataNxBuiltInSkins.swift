import SwiftUI

struct StrataNxBuiltInSkin: Identifiable {
    let id: String
    let title: String
    let tint: Color
    let portraitTemplateName: String? = nil

    static let all: [StrataNxBuiltInSkin] = [
        .init(id: "zelda", title: "Zelda", tint: Color(red: 0.20, green: 0.53, blue: 0.29)),
        .init(id: "mario", title: "Mario", tint: Color(red: 0.88, green: 0.16, blue: 0.14)),
        .init(id: "kirby", title: "Kirby", tint: Color(red: 0.95, green: 0.42, blue: 0.67)),
        .init(id: "luigi", title: "Luigi", tint: Color(red: 0.18, green: 0.55, blue: 0.29)),
        .init(id: "peach", title: "Peach", tint: Color(red: 0.96, green: 0.57, blue: 0.70)),
        .init(id: "bowser", title: "Bowser", tint: Color(red: 0.82, green: 0.25, blue: 0.12)),
        .init(id: "zelda-classic-edition", title: "Zelda Classic Edition", tint: Color(red: 0.20, green: 0.53, blue: 0.29), portraitTemplateName: "ZeldaClassicEdition"),
        .init(id: "zelda-1", title: "The Legend of Zelda", tint: Color(red: 0.83, green: 0.64, blue: 0.18)),
        .init(id: "adventure-of-link", title: "Zelda II: Adventure of Link", tint: Color(red: 0.60, green: 0.25, blue: 0.21)),
        .init(id: "a-link-to-the-past", title: "A Link to the Past", tint: Color(red: 0.28, green: 0.48, blue: 0.25)),
        .init(id: "links-awakening", title: "Link’s Awakening", tint: Color(red: 0.91, green: 0.54, blue: 0.69)),
        .init(id: "ocarina-of-time", title: "Ocarina of Time", tint: Color(red: 0.25, green: 0.48, blue: 0.33)),
        .init(id: "majoras-mask", title: "Majora’s Mask", tint: Color(red: 0.42, green: 0.31, blue: 0.62)),
        .init(id: "oracle-of-ages", title: "Oracle of Ages", tint: Color(red: 0.25, green: 0.49, blue: 0.77)),
        .init(id: "oracle-of-seasons", title: "Oracle of Seasons", tint: Color(red: 0.78, green: 0.28, blue: 0.20)),
        .init(id: "wind-waker", title: "The Wind Waker", tint: Color(red: 0.15, green: 0.61, blue: 0.78)),
        .init(id: "minish-cap", title: "The Minish Cap", tint: Color(red: 0.29, green: 0.58, blue: 0.30)),
        .init(id: "twilight-princess", title: "Twilight Princess", tint: Color(red: 0.34, green: 0.39, blue: 0.51)),
        .init(id: "phantom-hourglass", title: "Phantom Hourglass", tint: Color(red: 0.19, green: 0.58, blue: 0.75)),
        .init(id: "spirit-tracks", title: "Spirit Tracks", tint: Color(red: 0.28, green: 0.48, blue: 0.75)),
        .init(id: "skyward-sword", title: "Skyward Sword", tint: Color(red: 0.24, green: 0.51, blue: 0.78)),
        .init(id: "a-link-between-worlds", title: "A Link Between Worlds", tint: Color(red: 0.75, green: 0.40, blue: 0.54)),
        .init(id: "triforce-heroes", title: "Tri Force Heroes", tint: Color(red: 0.77, green: 0.47, blue: 0.24)),
        .init(id: "breath-of-the-wild", title: "Breath of the Wild", tint: Color(red: 0.24, green: 0.56, blue: 0.72)),
        .init(id: "tears-of-the-kingdom", title: "Tears of the Kingdom", tint: Color(red: 0.57, green: 0.52, blue: 0.26)),
        .init(id: "echoes-of-wisdom", title: "Echoes of Wisdom", tint: Color(red: 0.79, green: 0.47, blue: 0.61))
    ]
}
