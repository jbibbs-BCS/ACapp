struct VLAN: Codable, Identifiable, Equatable {
    let vlanId: Int
    let name: String?
    let taggedPorts: [String]
    let untaggedPorts: [String]

    var id: Int { vlanId }

    private enum CodingKeys: String, CodingKey {
        case vlanId        = "id"
        case name
        case taggedPorts
        case untaggedPorts
    }

    init(vlanId: Int, name: String?, taggedPorts: [String], untaggedPorts: [String]) {
        self.vlanId = vlanId; self.name = name
        self.taggedPorts = taggedPorts; self.untaggedPorts = untaggedPorts
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // API returns id as a String e.g. "1", "100"
        if let idInt = try? c.decode(Int.self, forKey: .vlanId) {
            vlanId = idInt
        } else {
            let idStr = (try? c.decode(String.self, forKey: .vlanId)) ?? "0"
            vlanId = Int(idStr) ?? 0
        }
        name          = try? c.decode(String.self,   forKey: .name)
        taggedPorts   = (try? c.decode([String].self, forKey: .taggedPorts))   ?? []
        untaggedPorts = (try? c.decode([String].self, forKey: .untaggedPorts)) ?? []
    }
}
