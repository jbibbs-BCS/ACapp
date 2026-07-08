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
        // Overview uses the CentralSwitch passed from the list — no per-switch detail endpoint exists.
        // Stacked switches require stackId; standalone switches use serial.
        detailState = .loaded(sw)
        portsState  = .loading
        vlansState  = .loading

        let deviceId = sw.stackId ?? sw.serial

        async let interfaces = client.fetchSwitchInterfaces(serial: deviceId)
        async let vlans      = client.fetchSwitchVLANs(serial: deviceId)

        do {
            portsState = .loaded(try await interfaces)
        } catch let e as APIError {
            portsState = .error(e)
        } catch {
            portsState = .error(.networkError)
        }

        do {
            vlansState = .loaded(try await vlans)
        } catch {
            // VLAN data is not available for all switch types; show empty rather than error.
            vlansState = .loaded([])
        }
    }

    func refresh() async { await load() }
}
