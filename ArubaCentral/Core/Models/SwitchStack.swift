import Foundation

/// A group of switches that form a single stack, presented as one logical device.
struct SwitchStack: Identifiable, Equatable, Hashable {
    let stackId: String
    let members: [CentralSwitch]

    var id: String { stackId }

    /// The conductor/master if the API identifies one, otherwise the first member.
    var representative: CentralSwitch {
        members.first(where: { $0.isConductor }) ?? members[0]
    }

    /// Row title — the conductor's name (falls back to the representative's).
    var name: String { representative.name }

    /// Model shown on the row — the representative's model.
    var model: String { representative.model }

    var memberCount: Int { members.count }

    /// Aggregate status: down if any member is down, up only if all members are up,
    /// otherwise unknown.
    var status: DeviceStatus {
        if members.contains(where: { $0.status == .down }) { return .down }
        if members.allSatisfy({ $0.status == .up })        { return .up }
        return .unknown
    }

    var siteName: String? { representative.siteName }
}

/// A single entry in a switch list: either a standalone switch or a stack.
enum SwitchListEntry: Identifiable, Equatable, Hashable {
    case standalone(CentralSwitch)
    case stack(SwitchStack)

    var id: String {
        switch self {
        case .standalone(let sw): return sw.id
        case .stack(let stack):   return "stack-\(stack.id)"
        }
    }
}

extension Array where Element == CentralSwitch {
    /// Groups a flat switch list into standalone switches and stacks.
    ///
    /// The New Central `/switches` endpoint returns one row per physical member,
    /// each stacked member sharing a `stackId`. Members are collapsed into a single
    /// `SwitchStack`; switches without a `stackId` remain standalone. First-seen
    /// order is preserved, so a stack appears where its first member appeared.
    func groupedIntoStacks() -> [SwitchListEntry] {
        var entries: [SwitchListEntry] = []
        var stackIndex: [String: Int] = [:]        // stackId -> index into `entries`
        var membersByStack: [String: [CentralSwitch]] = [:]

        for sw in self {
            guard let stackId = sw.stackId else {
                entries.append(.standalone(sw))
                continue
            }
            membersByStack[stackId, default: []].append(sw)
            if let idx = stackIndex[stackId] {
                entries[idx] = .stack(SwitchStack(stackId: stackId, members: membersByStack[stackId]!))
            } else {
                stackIndex[stackId] = entries.count
                entries.append(.stack(SwitchStack(stackId: stackId, members: membersByStack[stackId]!)))
            }
        }
        return entries
    }
}
