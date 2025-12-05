import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "shield.fill")
                    Text("VPN")
                }
                .tag(Tab.home)

            DashboardView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "rectangle.stack.fill")
                    Text("Dashboard")
                }
                .tag(Tab.dashboard)

            TopologyView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                    Text("Topology")
                }
                .tag(Tab.topology)

            AccountView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
                .tag(Tab.account)
        }
        .tint(.accentColor)
        .onAppear {
            appState.loadData()
        }
    }
}

enum Tab {
    case home
    case dashboard
    case topology
    case account
}

@MainActor
class AppState: ObservableObject {
    @Published var networks: [Network] = []
    @Published var selectedNetwork: Network?
    @Published var devices: [Device] = []
    @Published var relays: [Relay] = []
    @Published var selectedRelay: Relay?
    @Published var exitNodeConfig: ExitNodeConfig?
    @Published var user: User?
    @Published var isLoading = false
    @Published var selectedTab: Tab = .home

    func loadData() {
        Task {
            isLoading = true
            await loadNetworks()
            await loadRelays()
            await loadUser()
            isLoading = false
        }
    }

    func loadNetworks() async {
        do {
            networks = try await APIClient.shared.getNetworks()
            if selectedNetwork == nil, let first = networks.first {
                selectedNetwork = first
                await loadDevices()
                await loadExitNode()
            }
        } catch {
            print("Failed to load networks: \(error)")
        }
    }

    func loadDevices() async {
        guard let network = selectedNetwork else { return }
        do {
            devices = try await APIClient.shared.getDevices(networkId: network.id)
        } catch {
            print("Failed to load devices: \(error)")
        }
    }

    func loadRelays() async {
        do {
            relays = try await APIClient.shared.getRelays()
        } catch {
            print("Failed to load relays: \(error)")
        }
    }

    func loadExitNode() async {
        guard let network = selectedNetwork else { return }
        do {
            exitNodeConfig = try await APIClient.shared.getExitNode(networkId: network.id)
            if let config = exitNodeConfig, let relay = config.relay {
                selectedRelay = relay
            } else if let relayId = exitNodeConfig?.exitRelayId {
                selectedRelay = relays.first { $0.id == relayId }
            }
        } catch {
            print("Failed to load exit node: \(error)")
        }
    }

    func loadUser() async {
        do {
            user = try await APIClient.shared.getUser()
        } catch {
            print("Failed to load user: \(error)")
        }
    }

    func selectNetwork(_ network: Network) {
        selectedNetwork = network
        Task {
            await loadDevices()
            await loadExitNode()
        }
    }

    func selectRelay(_ relay: Relay) async {
        guard let network = selectedNetwork else { return }
        do {
            exitNodeConfig = try await APIClient.shared.setExitNode(
                networkId: network.id,
                exitType: "relay",
                relayId: relay.id
            )
            selectedRelay = relay
        } catch {
            print("Failed to set exit node: \(error)")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(VPNManager.shared)
}
