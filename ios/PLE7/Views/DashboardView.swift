import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Network Header
                    if let network = appState.selectedNetwork {
                        NetworkHeaderCard(network: network)
                    }

                    // Devices Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Devices")
                                .font(.headline)
                            Spacer()
                            Text("\(appState.devices.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }

                        if appState.devices.isEmpty {
                            EmptyDevicesCard()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(appState.devices) { device in
                                    DeviceCard(device: device)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await appState.loadDevices() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

struct NetworkHeaderCard: View {
    let network: Network

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "network")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(network.name)
                        .font(.headline)
                    Text(network.ipRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }

                Spacer()
            }

            if let description = network.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct EmptyDevicesCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No Devices")
                .font(.headline)
            Text("Add devices to this network via the web dashboard at ple7.com")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct DeviceCard: View {
    let device: Device
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        HStack(spacing: 14) {
            // Platform Icon
            ZStack {
                Circle()
                    .fill(isCurrentDevice ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemBackground))
                    .frame(width: 44, height: 44)
                Image(systemName: platformIcon)
                    .font(.title3)
                    .foregroundColor(isCurrentDevice ? .accentColor : .secondary)
            }

            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.body)
                        .fontWeight(.medium)

                    if isCurrentDevice {
                        Text("This device")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text(device.ip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)

                    if device.isExitNode {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .font(.caption2)
                            Text("Exit")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var isCurrentDevice: Bool {
        device.platform == "IOS"
    }

    private var statusColor: Color {
        if isCurrentDevice && vpnManager.isConnected {
            return .green
        }
        return .gray.opacity(0.5)
    }

    private var platformIcon: String {
        switch device.platform {
        case "IOS": return "iphone"
        case "MACOS": return "laptopcomputer"
        case "WINDOWS": return "pc"
        case "LINUX": return "server.rack"
        case "ANDROID": return "candybarphone"
        case "ROUTER": return "wifi.router"
        case "FIREWALL": return "firewall"
        default: return "desktopcomputer"
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(VPNManager.shared)
}
