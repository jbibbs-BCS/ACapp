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
        detailState = .loading
        portsState  = .loading
        vlansState  = .loading
        do {
            async let detail     = client.fetchSwitchDetail(serial: sw.serial)
            async let interfaces = client.fetchSwitchInterfaces(serial: sw.serial)
            async let vlans      = client.fetchSwitchVLANs(serial: sw.serial)
            let (d, i, v) = try await (detail, interfaces, vlans)
            detailState = .loaded(d)
            portsState  = .loaded(i)
            vlansState  = .loaded(v)
        } catch let error as APIError {
            detailState = .error(error)
        } catch {
            detailState = .error(.networkError)
        }
    }

    func refresh() async { await load() }
}
