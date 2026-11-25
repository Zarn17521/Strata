import SwiftUI

struct StrataNxBuiltInSkin: Identifiable {
    let id: String
    let title: String
    static let all: [StrataNxBuiltInSkin] = [
        .init(id: "zelda", title: "Zelda"),
        .init(id: "mario", title: "Mario"),
        .init(id: "kirby", title: "Kirby"),
        .init(id: "luigi", title: "Luigi"),
        .init(id: "peach", title: "Peach"),
        .init(id: "bowser", title: "Bowser"),
        .init(id: "zelda-classic-edition", title: "Zelda Classic Edition"),
        .init(id: "zelda-1", title: "The Legend of Zelda"),
        .init(id: "adventure-of-link", title: "Zelda II: Adventure of Link"),
        .init(id: "a-link-to-the-past", title: "A Link to the Past"),
        .init(id: "links-awakening", title: "Link’s Awakening"),
        .init(id: "ocarina-of-time", title: "Ocarina of Time"),
        .init(id: "majoras-mask", title: "Majora’s Mask"),
        .init(id: "oracle-of-ages", title: "Oracle of Ages"),
        .init(id: "oracle-of-seasons", title: "Oracle of Seasons"),
        .init(id: "wind-waker", title: "The Wind Waker"),
        .init(id: "minish-cap", title: "The Minish Cap"),
        .init(id: "twilight-princess", title: "Twilight Princess"),
        .init(id: "phantom-hourglass", title: "Phantom Hourglass"),
        .init(id: "spirit-tracks", title: "Spirit Tracks"),
        .init(id: "skyward-sword", title: "Skyward Sword"),
        .init(id: "a-link-between-worlds", title: "A Link Between Worlds"),
        .init(id: "triforce-heroes", title: "Tri Force Heroes"),
        .init(id: "breath-of-the-wild", title: "Breath of the Wild"),
        .init(id: "tears-of-the-kingdom", title: "Tears of the Kingdom"),
        .init(id: "echoes-of-wisdom", title: "Echoes of Wisdom")
    ]
}
