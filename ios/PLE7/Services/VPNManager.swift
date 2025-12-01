import Foundation
import NetworkExtension
import KeychainAccess

@MainActor
class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectedNetwork: String?
    @Published var connectedNetworkId: String?
    @Published var selectedDevice: Device?
    @Published var selectedNetwork: Network?
    @Published var connectionError: String?

    private var vpnManager: NETunnelProviderManager?
    private let keychain = Keychain(service: "com.ple7.vpn", accessGroup: "group.com.ple7.vpn")

    private init() {
        Task {
            await loadVPNConfiguration()
            observeVPNStatus()
        }
    }

    func selectDevice(_ device: Device, network: Network) {
        selectedDevice = device
        selectedNetwork = network
    }

    func connect() async {
        guard let device = selectedDevice, let network = selectedNetwork else {
            connectionError = "No device selected"
            return
        }

        isConnecting = true
        connectionError = nil

        do {
            // Fetch device config from API
            let config = try await APIClient.shared.getDeviceConfig(deviceId: device.id)

            // Store WireGuard config in shared keychain for the extension
            let configData = try JSONEncoder().encode(config.wireGuard)
            try keychain.set(configData, key: "wireguardConfig")

            // Configure and start VPN
            try await configureVPN(config: config, networkName: network.name)
            try await startVPN()

            connectedNetwork = network.name
            connectedNetworkId = network.id
            isConnected = true
        } catch {
            connectionError = error.localizedDescription
            print("VPN connection failed: \(error)")
        }

        isConnecting = false
    }

    func disconnect() async {
        vpnManager?.connection.stopVPNTunnel()
        isConnected = false
        connectedNetwork = nil
        connectedNetworkId = nil
    }

    // MARK: - Private

    private func loadVPNConfiguration() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            vpnManager = managers.first ?? NETunnelProviderManager()
        } catch {
            print("Failed to load VPN configuration: \(error)")
            vpnManager = NETunnelProviderManager()
        }
    }

    private func configureVPN(config: DeviceConfig, networkName: String) async throws {
        guard let manager = vpnManager else { return }

        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "com.ple7.vpn.PacketTunnel"
        tunnelProtocol.serverAddress = config.wireGuard.peers.first?.endpoint ?? "ple7.com"

        // Pass minimal config - full config is in shared keychain
        tunnelProtocol.providerConfiguration = [
            "deviceId": config.device.id,
            "networkId": config.network.id
        ]

        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = "PLE7 - \(networkName)"
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
    }

    private func startVPN() async throws {
        guard let manager = vpnManager else {
            throw VPNError.notConfigured
        }

        try manager.connection.startVPNTunnel()
    }

    private func observeVPNStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }

            Task { @MainActor in
                switch connection.status {
                case .connected:
                    self?.isConnected = true
                    self?.isConnecting = false
                case .connecting:
                    self?.isConnecting = true
                case .disconnected:
                    self?.isConnected = false
                    self?.isConnecting = false
                    self?.connectedNetwork = nil
                    self?.connectedNetworkId = nil
                case .disconnecting:
                    self?.isConnecting = false
                case .invalid:
                    self?.isConnected = false
                    self?.isConnecting = false
                case .reasserting:
                    self?.isConnecting = true
                @unknown default:
                    break
                }
            }
        }
    }
}

enum VPNError: Error {
    case notConfigured
    case connectionFailed
    case configurationError
}
