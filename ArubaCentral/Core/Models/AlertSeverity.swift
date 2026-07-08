enum AlertSeverity: String, Codable, Comparable, Equatable {
    case critical = "Critical"
    case major = "Major"
    case minor = "Minor"
    case info = "Info"

    private var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .major:    return 1
        case .minor:    return 2
        case .info:     return 3
        }
    }

    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

import SwiftUI

extension AlertSeverity {
    var color: Color {
        switch self {
        case .critical: return .healthCritical
        case .major:    return .healthWarning   // amber #F59E0B — distinct from brandOrange
        case .minor:    return Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
        case .info:     return Color(.secondaryLabel)
        }
    }

    var systemImage: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .major:    return "exclamationmark.triangle.fill"
        case .minor:    return "exclamationmark.circle.fill"
        case .info:     return "info.circle.fill"
        }
    }
}
