import SwiftUI

enum FoodKind: String, CaseIterable, Identifiable, Hashable {
    case rice
    case egg
    case yogurt

    var id: String { rawValue }

    static let eatingOrder: [FoodKind] = [.rice, .egg, .yogurt]
    static let plateOrder: [FoodKind] = [.yogurt, .egg, .rice]

    var displayName: String {
        switch self {
        case .rice:
            "ごはん"
        case .egg:
            "卵焼き"
        case .yogurt:
            "ヨーグルト"
        }
    }

    var shortLabel: String {
        switch self {
        case .rice:
            "ごはん"
        case .egg:
            "たまご"
        case .yogurt:
            "ヨーグルト"
        }
    }

    var emoji: String {
        switch self {
        case .rice:
            "🍚"
        case .egg:
            "🍳"
        case .yogurt:
            "🥣"
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .rice:
            5
        case .egg:
            5
        case .yogurt:
            4
        }
    }

    var displayColor: Color {
        switch self {
        case .rice:
            Color(red: 0.96, green: 0.93, blue: 0.82)
        case .egg:
            Color(red: 1.0, green: 0.79, blue: 0.16)
        case .yogurt:
            Color(red: 0.73, green: 0.64, blue: 0.93)
        }
    }
}
