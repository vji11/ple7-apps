import Foundation

@MainActor
class NetworksViewModel: ObservableObject {
    @Published var networks: [Network] = []
    @Published var selectedNetwork: Network?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadNetworks() {
        isLoading = true
        errorMessage = nil

        Task {
            await loadNetworksAsync()
        }
    }

    func loadNetworksAsync() async {
        do {
            let fetchedNetworks = try await APIClient.shared.getNetworks()
            networks = fetchedNetworks
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Failed to load networks"
        }
        isLoading = false
    }
}
