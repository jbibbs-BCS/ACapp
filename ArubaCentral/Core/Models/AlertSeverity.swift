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
        case .critical: return .red
        case .major:    return .orange
        case .minor:    return .yellow
        case .info:     return .blue
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
