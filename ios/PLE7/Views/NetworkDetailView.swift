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

                // Devices Section
                Section {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if viewModel.devices.isEmpty {
                        Text("No devices in this network")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.devices) { device in
                            DeviceRow(device: device, isSelected: vpnManager.selectedDevice?.id == device.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectDevice(device)
                                }
                        }
                    }
                } header: {
                    Text("Devices")
                } footer: {
                    Text("Select a device to connect as")
                }

                // Connect Section
                if vpnManager.selectedDevice != nil && viewModel.devices.contains(where: { $0.id == vpnManager.selectedDevice?.id }) {
                    Section {
                        Button(action: connectToNetwork) {
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
                viewModel.loadDevices()
            }
        }
    }

    private func selectDevice(_ device: Device) {
        vpnManager.selectDevice(device, network: network)
    }

    private func connectToNetwork() {
        Task {
            if vpnManager.connectedNetworkId == network.id {
                await vpnManager.disconnect()
            } else {
                await vpnManager.connect()
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Device Icon
            Image(systemName: platformIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Device Info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(device.ip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if device.platform == "IOS" {
                        Text("This device")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var platformIcon: String {
        switch device.platform {
        case "IOS": return "iphone"
        case "MACOS": return "laptopcomputer"
        case "WINDOWS": return "pc"
        case "LINUX": return "server.rack"
        case "ANDROID": return "candybarphone"
        default: return "desktopcomputer"
        }
    }
}

class NetworkDetailViewModel: ObservableObject {
    let networkId: String
    @Published var devices: [Device] = []
    @Published var isLoading = false

    init(networkId: String) {
        self.networkId = networkId
    }

    func loadDevices() {
        isLoading = true
        Task {
            do {
                let fetchedDevices = try await APIClient.shared.getDevices(networkId: networkId)
                await MainActor.run {
                    self.devices = fetchedDevices
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load devices: \(error)")
            }
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
