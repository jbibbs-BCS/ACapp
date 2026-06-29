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
        do {
            async let detail  = client.fetchAPDetail(serial: ap.serial)
            async let radios  = client.fetchAPRadios(serial: ap.serial)
            async let clients = client.fetchAPClients(serial: ap.serial, limit: 100, offset: 0)
            let (d, r, c) = try await (detail, radios, clients)
            detailState  = .loaded(d)
            radiosState  = .loaded(r)
            clientsState = .loaded(c.items)
        } catch let error as APIError {
            detailState  = .error(error)
            radiosState  = .error(error)
            clientsState = .error(error)
        } catch {
            detailState  = .error(.networkError)
            radiosState  = .error(.networkError)
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
