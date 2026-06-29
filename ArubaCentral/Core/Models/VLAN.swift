struct VLAN: Codable, Identifiable, Equatable {
    let vlanId: Int
    let name: String?
    let taggedPorts: [String]
    let untaggedPorts: [String]

    var id: Int { vlanId }

    enum CodingKeys: String, CodingKey {
        case vlanId        = "vlan_id"
        case name          = "vlan_name"
        case taggedPorts   = "tagged_ports"
        case untaggedPorts = "untagged_ports"
    }
}
