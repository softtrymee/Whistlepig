//
// Copyright 2026 Whistlepig
//

import Foundation
import SwiftUI

enum WhistlepigAccent: String, CaseIterable, Codable, Identifiable {
    case iris
    case lagoon
    case sakura
    case rose
    case matcha
    case mint
    case amber
    case coral
    case lavender
    case graphite
    
    var id: Self {
        self
    }
    
    static var current: Self {
        guard let store = UserDefaults(suiteName: AppSettings.suiteName),
              let rawValue = store.string(forKey: "whistlepigAccent"),
              let accent = Self(rawValue: rawValue) else {
            return .iris
        }
        return accent
    }
    
    var name: String {
        switch self {
        case .iris: "Iris"
        case .lagoon: "Ocean"
        case .sakura: "Sakura"
        case .rose: "Rose"
        case .matcha: "Matcha"
        case .mint: "Mint"
        case .amber: "Amber"
        case .coral: "Coral"
        case .lavender: "Lavender"
        case .graphite: "Graphite"
        }
    }
    
    var primary: Color {
        switch self {
        case .iris: Color(red: 112 / 255, green: 108 / 255, blue: 246 / 255)
        case .lagoon: Color(red: 58 / 255, green: 145 / 255, blue: 201 / 255)
        case .sakura: Color(red: 218 / 255, green: 134 / 255, blue: 164 / 255)
        case .rose: Color(red: 194 / 255, green: 83 / 255, blue: 119 / 255)
        case .matcha: Color(red: 104 / 255, green: 151 / 255, blue: 112 / 255)
        case .mint: Color(red: 65 / 255, green: 168 / 255, blue: 151 / 255)
        case .amber: Color(red: 202 / 255, green: 137 / 255, blue: 68 / 255)
        case .coral: Color(red: 211 / 255, green: 107 / 255, blue: 91 / 255)
        case .lavender: Color(red: 151 / 255, green: 128 / 255, blue: 201 / 255)
        case .graphite: Color(red: 101 / 255, green: 108 / 255, blue: 122 / 255)
        }
    }
    
    var soft: Color {
        Color(uiColor: UIColor { traits in
            let alpha = traits.userInterfaceStyle == .dark ? 0.26 : 0.14
            return UIColor(primary).withAlphaComponent(alpha)
        })
    }
}

private struct WhistlepigAccentKey: EnvironmentKey {
    static let defaultValue = WhistlepigAccent.iris
}

extension EnvironmentValues {
    var whistlepigAccent: WhistlepigAccent {
        get { self[WhistlepigAccentKey.self] }
        set { self[WhistlepigAccentKey.self] = newValue }
    }
}
