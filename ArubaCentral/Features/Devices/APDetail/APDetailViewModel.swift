@preconcurrency import Foundation
import Combine

@MainActor
final class APDetailViewModel: ObservableObject {
    @Published private(set) var detailState:  LoadState<AccessPoint>     = .idle
    @Published private(set) var radiosState:  LoadState<[Radio]>         = .idle
    @Published private(set) var clientsState: LoadState<[CentralClient]> = .idle
    @Published var actionError: APIError?   = nil
    @Published var showingRebootConfirm     = false
    @Published var showingBlinkConfirm      = false

    let ap: AccessPoint
    private let client: CentralAPIClientProtocol

    init(ap: AccessPoint, apiClient: CentralAPIClientProtocol) {
        self.ap     = ap
        self.client = apiClient
    }

    func load() async {
        detailState  = .loading
        radiosState  = .loading
        clientsState = .loading
        // Load detail + radios together; clients separately so rate-limiting
        // on the paginated client fetch never breaks the Overview/Radios tabs.
        async let detailTask = client.fetchAPDetail(serial: ap.serial)
        async let radiosTask = client.fetchAPRadios(serial: ap.serial)
        do {
            let (d, r) = try await (detailTask, radiosTask)
            detailState = .loaded(d)
            radiosState = .loaded(r)
        } catch let error as APIError {
            detailState  = .error(error)
            radiosState  = .error(error)
            clientsState = .error(error)
            return
        } catch {
            detailState  = .error(.networkError)
            radiosState  = .error(.networkError)
            clientsState = .error(.networkError)
            return
        }
        do {
            let c = try await client.fetchAPClients(serial: ap.serial, limit: 100, next: nil)
            clientsState = .loaded(c.items)
        } catch let error as APIError {
            clientsState = .error(error)
        } catch {
            clientsState = .error(.networkError)
        }
    }

    func rebootAP() async {
        do {
            try await client.rebootAP(serial: ap.serial)
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }

    func blinkLED() async {
        do {
            try await client.blinkAPLED(serial: ap.serial)
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }
}
