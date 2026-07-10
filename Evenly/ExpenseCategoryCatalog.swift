import Foundation

enum ExpenseIconType: String, Codable {
    case sfSymbol = "sf_symbol"
    case emoji
}

struct ExpenseIcon: Identifiable, Hashable, Codable {
    let type: ExpenseIconType
    let value: String

    var id: String { "\(type.rawValue):\(value)" }
}

struct ExpenseCategoryPreset: Identifiable, Hashable {
    let name: String
    let category: String
    let icon: ExpenseIcon

    var id: String { name }
}

struct ExpenseCategoryGroup: Identifiable {
    let name: String
    let icon: ExpenseIcon
    let items: [ExpenseCategoryPreset]

    var id: String { name }
}

enum ExpenseCategoryCatalog {
    static let categories: [ExpenseCategoryGroup] = [
        group("餐饮", "fork.knife", [("早餐", "sunrise.fill"), ("午餐", "sun.max.fill"), ("晚餐", "moon.stars.fill"), ("咖啡", "cup.and.saucer.fill")]),
        group("交通", "tram.fill", [("打车", "car.fill"), ("高铁", "train.side.front.car"), ("地铁", "tram.fill"), ("机票", "airplane")]),
        group("住宿", "bed.double.fill", [("住宿", "bed.double.fill"), ("酒店", "building.2.fill"), ("民宿", "house.fill"), ("门票", "ticket.fill")]),
        group("购物", "bag.fill", [("超市", "cart.fill"), ("购物", "bag.fill"), ("礼物", "gift.fill")]),
        group("娱乐", "gamecontroller.fill", [("娱乐", "gamecontroller.fill"), ("电影", "film.fill"), ("音乐", "music.note")]),
        group("其他", "ellipsis.circle.fill", [("医疗", "cross.case.fill"), ("学习", "book.fill"), ("宠物", "pawprint.fill"), ("运动", "dumbbell.fill"), ("其他", "ellipsis.circle.fill")]),
    ]

    static let sfSymbolIcons: [ExpenseIcon] = Array(Set(categories.flatMap { group in
        [group.icon] + group.items.map(\.icon)
    })).sorted { $0.value < $1.value }

    static let emojiIcons: [ExpenseIcon] = [
        "🍜", "🍚", "🍔", "🍕", "☕️", "🍺", "🚕", "🚄", "🚇", "✈️",
        "⛽️", "🏨", "🏠", "🎫", "🛒", "🛍️", "🎁", "🎮", "🎬", "🎵",
        "🏥", "💊", "📚", "🎓", "🐾", "🏃", "🏋️", "💡", "💰", "🧾",
    ].map { ExpenseIcon(type: .emoji, value: $0) }

    static func preset(named name: String) -> ExpenseCategoryPreset? {
        categories.flatMap(\.items).first { $0.name == name }
    }

    static func defaultIcon(for category: String) -> ExpenseIcon? {
        categories.first { $0.name == category }?.icon
    }

    private static func group(_ name: String, _ icon: String, _ items: [(String, String)]) -> ExpenseCategoryGroup {
        ExpenseCategoryGroup(
            name: name,
            icon: ExpenseIcon(type: .sfSymbol, value: icon),
            items: items.map { ExpenseCategoryPreset(name: $0.0, category: name, icon: ExpenseIcon(type: .sfSymbol, value: $0.1)) }
        )
    }
}
