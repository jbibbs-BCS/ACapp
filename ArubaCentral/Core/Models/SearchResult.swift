import Foundation

enum SearchResult: Identifiable {
    case ap(AccessPoint)
    case switch_(CentralSwitch)
    case client(CentralClient)

    var id: String {
        switch self {
        case .ap(let ap):         return "ap-\(ap.serial)"
        case .switch_(let sw):    return "sw-\(sw.serial)"
        case .client(let client): return "cl-\(client.macAddress)"
        }
    }

    var displayName: String {
        switch self {
        case .ap(let ap):         return ap.name
        case .switch_(let sw):    return sw.name
        case .client(let client): return client.name ?? client.ipAddress ?? client.macAddress
        }
    }

    var systemImage: String {
        switch self {
        case .ap:      return "wifi"
        case .switch_: return "rectangle.connected.to.line.below"
        case .client:  return "person.circle"
        }
    }

    var siteName: String {
        switch self {
        case .ap(let ap):         return ap.siteName ?? ""
        case .switch_(let sw):    return sw.siteName ?? ""
        case .client(let client): return client.siteName ?? ""
        }
    }
}
