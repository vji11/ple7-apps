import SwiftUI

struct TopologyView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Internet Exit
                    TopologyNode(
                        icon: "globe",
                        title: "Internet",
                        subtitle: "Public network",
                        color: .blue,
                        isActive: vpnManager.isConnected
                    )

                    // Connection Line
                    TopologyConnector(isActive: vpnManager.isConnected)

                    // Relay Node
                    if let relay = appState.selectedRelay {
                        TopologyNode(
                            icon: "server.rack",
                            title: relay.name,
                            subtitle: "\(relay.flagEmoji) \(relay.location)",
                            color: .orange,
                            isActive: vpnManager.isConnected
                        )
                    } else {
                        TopologyNode(
                            icon: "server.rack",
                            title: "Relay Server",
                            subtitle: "Not selected",
                            color: .gray,
                            isActive: false
                        )
                    }

                    // Connection Line
                    TopologyConnector(isActive: vpnManager.isConnected)

                    // This Device
                    if let device = appState.devices.first(where: { $0.platform == "IOS" }) {
                        TopologyNode(
                            icon: "iphone",
                            title: device.name,
                            subtitle: device.ip,
                            color: .accentColor,
                            isActive: vpnManager.isConnected,
                            isThisDevice: true
                        )
                    } else {
                        TopologyNode(
                            icon: "iphone",
                            title: "This Device",
                            subtitle: "Not registered",
                            color: .gray,
                            isActive: false,
                            isThisDevice: true
                        )
                    }

                    // Other Devices Section
                    if !otherDevices.isEmpty {
                        VStack(spacing: 0) {
                            // Branch connector
                            TopologyBranch(deviceCount: otherDevices.count, isActive: vpnManager.isConnected)

                            // Other devices grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(otherDevices) { device in
                                    SmallDeviceNode(device: device)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 30)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Topology")
        }
    }

    private var otherDevices: [Device] {
        appState.devices.filter { $0.platform != "IOS" }
    }
}

struct TopologyNode: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isActive: Bool
    var isThisDevice: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(color.opacity(isActive ? 0.2 : 0.1))
                    .frame(width: 56, height: 56)
                Circle()
                    .stroke(color.opacity(isActive ? 1 : 0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isActive ? color : .gray)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)

                    if isThisDevice {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.15))
                            .foregroundColor(color)
                            .cornerRadius(4)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status dot
            if isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
}

struct TopologyConnector: View {
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 2, height: 24)

            if isActive {
                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }

            Rectangle()
                .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 2, height: 24)
        }
    }
}

struct TopologyBranch: View {
    let deviceCount: Int
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3))
                .frame(width: 2, height: 20)

            HStack(spacing: 0) {
                ForEach(0..<min(deviceCount, 4), id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(isActive ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                    Circle()
                        .fill(isActive ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: CGFloat(min(deviceCount, 4)) * 60)

            HStack(spacing: 60) {
                ForEach(0..<min(deviceCount, 4), id: \.self) { _ in
                    Rectangle()
                        .fill(isActive ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct SmallDeviceNode: View {
    let device: Device

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 44, height: 44)
                Image(systemName: platformIcon)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                Text(device.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(device.ip)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
    TopologyView()
        .environmentObject(AppState())
        .environmentObject(VPNManager.shared)
}
