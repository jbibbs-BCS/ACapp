import SwiftUI

extension Color {
    static let healthGood     = Color.green
    static let healthWarning  = Color.orange
    static let healthCritical = Color.red

    static func healthColor(for level: HealthLevel) -> Color {
        switch level {
        case .good:     return .healthGood
        case .warning:  return .healthWarning
        case .critical: return .healthCritical
        }
    }
}

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
