import Foundation

struct CentralRegion: Identifiable, Hashable {
    let id: String
    let label: String
    let baseURL: URL

    static let all: [CentralRegion] = [
        .init(id: "us1", label: "US-1",        baseURL: URL(string: "https://us1.api.central.arubanetworks.com")!),
        .init(id: "us2", label: "US-2",        baseURL: URL(string: "https://us2.api.central.arubanetworks.com")!),
        .init(id: "us4", label: "US-West-4",   baseURL: URL(string: "https://us4.api.central.arubanetworks.com")!),
        .init(id: "us5", label: "US-West-5",   baseURL: URL(string: "https://us5.api.central.arubanetworks.com")!),
        .init(id: "us6", label: "US-East-1",   baseURL: URL(string: "https://us6.api.central.arubanetworks.com")!),
        .init(id: "ca1", label: "Canada-1",    baseURL: URL(string: "https://ca1.api.central.arubanetworks.com")!),
        .init(id: "de1", label: "EU-1",        baseURL: URL(string: "https://de1.api.central.arubanetworks.com")!),
        .init(id: "de2", label: "EU-Central-2",baseURL: URL(string: "https://de2.api.central.arubanetworks.com")!),
        .init(id: "de3", label: "EU-Central-3",baseURL: URL(string: "https://de3.api.central.arubanetworks.com")!),
        .init(id: "gb1", label: "UK",          baseURL: URL(string: "https://gb1.api.central.arubanetworks.com")!),
        .init(id: "in1", label: "APAC-1",      baseURL: URL(string: "https://in1.api.central.arubanetworks.com")!),
        .init(id: "jp1", label: "APAC-East-1", baseURL: URL(string: "https://jp1.api.central.arubanetworks.com")!),
        .init(id: "au1", label: "APAC-South-1",baseURL: URL(string: "https://au1.api.central.arubanetworks.com")!),
        .init(id: "ae1", label: "UAE",         baseURL: URL(string: "https://ae1.api.central.arubanetworks.com")!),
    ]

    static let defaultRegion = all[0]
}
