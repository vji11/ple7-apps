import SwiftUI

struct NetworkDetailView: View {
    let network: Network
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var viewModel: NetworkDetailViewModel

    init(network: Network) {
        self.network = network
        _viewModel = StateObject(wrappedValue: NetworkDetailViewModel(networkId: network.id))
    }

    var body: some View {
        NavigationView {
            List {
                // Network Info Section
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(network.name)
                            .foregroundColor(.secondary)
                    }
                    if let description = network.description {
                        HStack {
                            Text("Description")
                            Spacer()
                            Text(description)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("IP Range")
                        Spacer()
                        Text(network.ipRange)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Network")
                }

                // Connection Status Section
                if vpnManager.connectedNetworkId == network.id {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected")
                                .foregroundColor(.green)
                            Spacer()
                            if let device = vpnManager.currentDevice {
                                Text(device.ip)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Status")
                    }
                }

                // Exit Node Selection Section
                Section {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        // None option (mesh only)
                        ExitNodeRow(
                            title: "None",
                            subtitle: "Mesh only - no exit node",
                            icon: "network",
                            isSelected: viewModel.selectedExitNode == nil
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedExitNode = nil
                        }

                        // PLE7 Relays
                        if !viewModel.relays.isEmpty {
                            Section {
                                ForEach(viewModel.relays) { relay in
                                    ExitNodeRow(
                                        title: "\(relay.flagEmoji) \(relay.location)",
                                        subtitle: relay.name,
                                        icon: "globe",
                                        isSelected: viewModel.isRelaySelected(relay),
                                        isOnline: relay.isOnline
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if relay.isOnline {
                                            viewModel.selectRelay(relay)
                                        }
                                    }
                                    .opacity(relay.isOnline ? 1 : 0.5)
                                }
                            } header: {
                                Text("PLE7 Relays")
                            }
                        }

                        // User's Exit Node Devices
                        if !viewModel.exitNodeDevices.isEmpty {
                            Section {
                                ForEach(viewModel.exitNodeDevices) { device in
                                    ExitNodeRow(
                                        title: device.name,
                                        subtitle: device.ip,
                                        icon: platformIcon(for: device.platform),
                                        isSelected: viewModel.isDeviceSelected(device)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectDevice(device)
                                    }
                                }
                            } header: {
                                Text("Your Devices")
                            }
                        }
                    }
                } header: {
                    Text("Exit Node")
                } footer: {
                    Text("Route all traffic through an exit node, or use mesh-only for direct device connections")
                }

                // Connect/Disconnect Button
                Section {
                    Button(action: handleConnectTap) {
                        HStack {
                            Spacer()
                            if vpnManager.isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(vpnManager.connectedNetworkId == network.id ? "Disconnect" : "Connect")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(vpnManager.connectedNetworkId == network.id ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .disabled(vpnManager.isConnecting)
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(network.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }

    private func handleConnectTap() {
        Task {
            if vpnManager.connectedNetworkId == network.id {
                await vpnManager.disconnect()
            } else {
                await viewModel.connect(network: network, vpnManager: vpnManager)
            }
        }
    }

    private func platformIcon(for platform: String) -> String {
        switch platform {
        case "ROUTER": return "wifi.router"
        case "FIREWALL": return "shield"
        case "SERVER": return "server.rack"
        case "DESKTOP", "MACOS", "WINDOWS", "LINUX": return "desktopcomputer"
        default: return "desktopcomputer"
        }
    }
}

// MARK: - Exit Node Row

struct ExitNodeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    var isOnline: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isOnline {
                Text("Offline")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class NetworkDetailViewModel: ObservableObject {
    let networkId: String

    @Published var relays: [Relay] = []
    @Published var exitNodeDevices: [Device] = []
    @Published var selectedExitNode: ExitNodeSelection?
    @Published var isLoading = false
    @Published var errorMessage: String?

    init(networkId: String) {
        self.networkId = networkId
    }

    func loadData() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                async let relaysTask = APIClient.shared.getRelays()
                async let devicesTask = APIClient.shared.getDevices(networkId: networkId)

                let (fetchedRelays, fetchedDevices) = try await (relaysTask, devicesTask)

                self.relays = fetchedRelays.filter { $0.isOnline }
                // Only show devices that are exit nodes (ROUTER, FIREWALL, SERVER)
                self.exitNodeDevices = fetchedDevices.filter { device in
                    device.isExitNode && ["ROUTER", "FIREWALL", "SERVER"].contains(device.platform)
                }
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func isRelaySelected(_ relay: Relay) -> Bool {
        guard let selection = selectedExitNode else { return false }
        return selection.type == .relay && selection.id == relay.id
    }

    func isDeviceSelected(_ device: Device) -> Bool {
        guard let selection = selectedExitNode else { return false }
        return selection.type == .device && selection.id == device.id
    }

    func selectRelay(_ relay: Relay) {
        selectedExitNode = ExitNodeSelection(type: .relay, id: relay.id)
    }

    func selectDevice(_ device: Device) {
        selectedExitNode = ExitNodeSelection(type: .device, id: device.id)
    }

    func connect(network: Network, vpnManager: VPNManager) async {
        errorMessage = nil

        do {
            // 1. Auto-register this device
            let deviceName = UIDevice.current.name
            let device = try await APIClient.shared.autoRegisterDevice(
                networkId: networkId,
                deviceName: deviceName
            )

            // 2. Set exit node if selected
            if let exitNode = selectedExitNode {
                try await APIClient.shared.setExitNode(
                    networkId: networkId,
                    type: exitNode.type,
                    exitId: exitNode.id
                )
            } else {
                try await APIClient.shared.setExitNode(
                    networkId: networkId,
                    type: .none,
                    exitId: nil
                )
            }

            // 3. Get WireGuard config and connect
            let configResponse = try await APIClient.shared.getDeviceConfig(deviceId: device.id)
            await vpnManager.connect(device: device, network: network, configString: configResponse.config)

        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NetworkDetailView(network: Network(
        id: "1",
        name: "Home Network",
        description: "My home mesh",
        ipRange: "10.100.0.0/27",
        deviceCount: 3
    ))
    .environmentObject(VPNManager.shared)
}
