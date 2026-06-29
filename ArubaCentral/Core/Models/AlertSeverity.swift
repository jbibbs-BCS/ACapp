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
