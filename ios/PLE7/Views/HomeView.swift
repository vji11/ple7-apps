import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // VPN Status Card
                    VPNStatusSection()

                    // Network Selection
                    NetworkSelectionSection()

                    // Relay Selection
                    RelaySelectionSection()

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("PLE7 VPN")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { appState.loadData() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

struct VPNStatusSection: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(statusColor)
                    .frame(width: 80, height: 80)
                Image(systemName: statusIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }

            // Status Text
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let relay = appState.selectedRelay, vpnManager.isConnected {
                    Text("\(relay.flagEmoji) \(relay.location)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Connect Button
            Button(action: toggleVPN) {
                HStack {
                    if vpnManager.isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(vpnManager.isConnected ? "Disconnect" : "Connect")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(vpnManager.isConnected ? Color.red : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(vpnManager.isConnecting || appState.selectedNetwork == nil || currentDevice == nil)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var currentDevice: Device? {
        appState.devices.first { $0.platform == "IOS" }
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
            return "shield.slash.fill"
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
                if let device = currentDevice, let network = appState.selectedNetwork {
                    vpnManager.selectDevice(device, network: network)
                    await vpnManager.connect()
                }
            }
        }
    }
}

struct NetworkSelectionSection: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNetworkPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: { showingNetworkPicker = true }) {
                HStack {
                    Image(systemName: "network")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.selectedNetwork?.name ?? "Select Network")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        if let network = appState.selectedNetwork {
                            Text("\(network.deviceCount) device\(network.deviceCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingNetworkPicker) {
            NetworkPickerSheet()
        }
    }
}

struct NetworkPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(appState.networks) { network in
                    Button(action: {
                        appState.selectNetwork(network)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(network.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("\(network.deviceCount) device\(network.deviceCount == 1 ? "" : "s") - \(network.ipRange)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if appState.selectedNetwork?.id == network.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RelaySelectionSection: View {
    @EnvironmentObject var appState: AppState
    @State private var showingRelayPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exit Location")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: { showingRelayPicker = true }) {
                HStack {
                    if let relay = appState.selectedRelay {
                        Text(relay.flagEmoji)
                            .font(.title2)
                            .frame(width: 32)
                    } else {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 32)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.selectedRelay?.name ?? "Select Exit Location")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        if let relay = appState.selectedRelay {
                            Text(relay.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingRelayPicker) {
            RelayPickerSheet()
        }
    }
}

struct RelayPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isUpdating = false

    var body: some View {
        NavigationView {
            List {
                ForEach(appState.relays.filter { $0.status == "online" }) { relay in
                    Button(action: {
                        selectRelay(relay)
                    }) {
                        HStack {
                            Text(relay.flagEmoji)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(relay.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(relay.location)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isUpdating && appState.selectedRelay?.id == relay.id {
                                ProgressView()
                            } else if appState.selectedRelay?.id == relay.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isUpdating)
                }
            }
            .navigationTitle("Select Exit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func selectRelay(_ relay: Relay) {
        isUpdating = true
        Task {
            await appState.selectRelay(relay)
            isUpdating = false
            dismiss()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(VPNManager.shared)
        .environmentObject(AppState())
}
