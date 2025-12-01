import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var viewModel = NetworksViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // VPN Status Card
                VPNStatusCard()
                    .padding()

                // Networks List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading networks...")
                    Spacer()
                } else if viewModel.networks.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Networks")
                            .font(.headline)
                        Text("Create a network on ple7.com to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.networks) { network in
                            NetworkRow(network: network)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedNetwork = network
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("PLE7")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.loadNetworks() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Divider()
                        Button(role: .destructive, action: { authManager.logout() }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.loadNetworksAsync()
            }
            .sheet(item: $viewModel.selectedNetwork) { network in
                NetworkDetailView(network: network)
            }
        }
        .onAppear {
            viewModel.loadNetworks()
        }
    }
}

struct VPNStatusCard: View {
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        VStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(statusColor)
                    .frame(width: 60, height: 60)
                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            // Status Text
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.headline)
                if let network = vpnManager.connectedNetwork {
                    Text(network)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Connect/Disconnect Button
            Button(action: toggleVPN) {
                Text(vpnManager.isConnected ? "Disconnect" : "Connect")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(vpnManager.isConnected ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(vpnManager.isConnecting || vpnManager.selectedDevice == nil)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var statusColor: Color {
        if vpnManager.isConnected {
            return .green
        } else if vpnManager.isConnecting {
            return .orange
        } else {
            return .gray
        }
    }

    private var statusIcon: String {
        if vpnManager.isConnected {
            return "checkmark.shield.fill"
        } else if vpnManager.isConnecting {
            return "hourglass"
        } else {
            return "shield.slash"
        }
    }

    private var statusText: String {
        if vpnManager.isConnected {
            return "Connected"
        } else if vpnManager.isConnecting {
            return "Connecting..."
        } else {
            return "Not Connected"
        }
    }

    private func toggleVPN() {
        Task {
            if vpnManager.isConnected {
                await vpnManager.disconnect()
            } else {
                await vpnManager.connect()
            }
        }
    }
}

struct NetworkRow: View {
    let network: Network
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        HStack(spacing: 12) {
            // Network Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "network")
                    .foregroundColor(.accentColor)
            }

            // Network Info
            VStack(alignment: .leading, spacing: 4) {
                Text(network.name)
                    .font(.headline)
                Text("\(network.deviceCount) device\(network.deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Connected Indicator
            if vpnManager.connectedNetworkId == network.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainView()
        .environmentObject(AuthManager.shared)
        .environmentObject(VPNManager.shared)
}
