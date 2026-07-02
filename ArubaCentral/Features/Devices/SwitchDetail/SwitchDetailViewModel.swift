import Foundation
import Combine

@MainActor
final class SwitchDetailViewModel: ObservableObject {
    @Published private(set) var detailState: LoadState<CentralSwitch>     = .idle
    @Published private(set) var portsState:  LoadState<[SwitchInterface]> = .idle
    @Published private(set) var vlansState:  LoadState<[VLAN]>            = .idle
    @Published var actionError: APIError? = nil

    let sw: CentralSwitch
    private let client: CentralAPIClientProtocol

    init(sw: CentralSwitch, apiClient: CentralAPIClientProtocol) {
        self.sw     = sw
        self.client = apiClient
    }

    func load() async {
        // Overview uses the CentralSwitch passed from the list — no per-switch detail endpoint exists
        detailState = .loaded(sw)
        portsState  = .loading
        vlansState  = .loading
        do {
            async let interfaces = client.fetchSwitchInterfaces(serial: sw.serial)
            async let vlans      = client.fetchSwitchVLANs(serial: sw.serial)
            let (i, v) = try await (interfaces, vlans)
            portsState = .loaded(i)
            vlansState = .loaded(v)
        } catch let error as APIError {
            portsState = .error(error)
            vlansState = .error(error)
        } catch {
            portsState = .error(.networkError)
            vlansState = .error(.networkError)
        }
    }

    func refresh() async { await load() }
}
