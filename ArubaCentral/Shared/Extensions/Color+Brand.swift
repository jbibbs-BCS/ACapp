import SwiftUI
import UIKit

// MARK: - Surface tokens

extension Color {
    static let appBackground: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.039, green: 0.118, blue: 0.220, alpha: 1)  // #0A1E38
            : UIColor(red: 0.949, green: 0.945, blue: 0.937, alpha: 1)  // #F2F1EF
    })

    static let cardBackground: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.067, green: 0.145, blue: 0.251, alpha: 1)  // #112540
            : UIColor.white
    })

    static let navBackground: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.027, green: 0.082, blue: 0.149, alpha: 1)  // #071526
            : UIColor(red: 0.051, green: 0.153, blue: 0.302, alpha: 1)  // #0D274D
    })

    static let cardBorder: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor(red: 0.051, green: 0.153, blue: 0.302, alpha: 0.10)
    })
}

// MARK: - Brand accent tokens

extension Color {
    static let brandOrange      = Color(red: 1.000, green: 0.514, blue: 0.000) // #FF8300
    static let brandNavy        = Color(red: 0.051, green: 0.153, blue: 0.302) // #0D274D
    static let brandOrangeMuted = Color(UIColor(red: 1.000, green: 0.514, blue: 0.000, alpha: 0.12))
    static let brandSectionHeader: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.7)
            : UIColor(red: 0.051, green: 0.153, blue: 0.302, alpha: 1)
    })
}

// MARK: - Health / status tokens (names unchanged — all existing call sites compile without modification)

extension Color {
    static let healthGood: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1)  // #4ADE80
            : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)  // #22C55E
    })

    static let healthWarning: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.988, green: 0.827, blue: 0.302, alpha: 1)  // #FCD34D
            : UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)  // #F59E0B — amber, distinct from brandOrange
    })

    static let healthCritical: Color = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1)  // #F87171
            : UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)  // #EF4444
    })

    static func healthColor(for level: HealthLevel) -> Color {
        switch level {
        case .good:     return .healthGood
        case .warning:  return .healthWarning
        case .critical: return .healthCritical
        }
    }
}

// MARK: - HealthLevel display extensions (moved from Color+Health.swift)

extension HealthLevel {
    var accessibilityLabel: String {
        switch self {
        case .good:     return "Good"
        case .warning:  return "Warning"
        case .critical: return "Critical"
        }
    }

    var systemImage: String {
        switch self {
        case .good:     return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}
