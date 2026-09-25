import Foundation
import SwiftUI
import WidgetKit

/// Reads the App Group suite the main app writes via `WidgetSnapshot`.
enum WidgetDefaults {
    static let appGroupID = "group.com.codefixr.beummati"

    static var suite: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func string(_ key: String) -> String? {
        suite.string(forKey: key).flatMap { $0.isEmpty ? nil : $0 }
    }

    static func double(_ key: String) -> Double {
        suite.double(forKey: key)
    }
}

enum WidgetPalette {
    static let teal = Color(red: 0.12, green: 0.42, blue: 0.40)
    static let ink = Color(red: 0.14, green: 0.16, blue: 0.18)
    static let secondary = Color(red: 0.35, green: 0.38, blue: 0.40)
    static let parchment = Color(red: 0.96, green: 0.94, blue: 0.90)
}

extension View {
    func widgetCardBackground() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(WidgetPalette.parchment)
    }
}
