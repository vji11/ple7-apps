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
    @Published var currentDevice: Device?
    @Published var connectionError: String?

    private var vpnManager: NETunnelProviderManager?
    private let keychain = Keychain(service: "com.ple7.vpn", accessGroup: "group.com.ple7.vpn")

    private init() {
        Task {
            await loadVPNConfiguration()
            observeVPNStatus()
        }
    }

    /// Connect to VPN with the given device and WireGuard config string
    func connect(device: Device, network: Network, configString: String) async {
        isConnecting = true
        connectionError = nil

        do {
            // Parse the WireGuard config string and store for the extension
            let wgConfig = parseWireGuardConfig(configString)
            let configData = try JSONEncoder().encode(wgConfig)
            try keychain.set(configData, key: "wireguardConfig")

            // Configure and start VPN
            try await configureVPN(configString: configString, networkName: network.name)
            try await startVPN()

            currentDevice = device
            connectedNetwork = network.name
            connectedNetworkId = network.id
            isConnected = true
        } catch {
            connectionError = error.localizedDescription
            print("VPN connection failed: \(error)")
        }

        isConnecting = false
    }

    /// Parse WireGuard INI-style config string into structured data
    private func parseWireGuardConfig(_ configString: String) -> WireGuardConfigData {
        var privateKey = ""
        var address = ""
        var dns: String? = nil
        var peers: [WireGuardPeerData] = []

        var currentSection = ""
        var currentPeer: (publicKey: String, allowedIPs: String, endpoint: String?, persistentKeepalive: Int?) = ("", "", nil, nil)

        for line in configString.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Check for section headers
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                // Save previous peer if exists
                if currentSection == "Peer" && !currentPeer.publicKey.isEmpty {
                    peers.append(WireGuardPeerData(
                        publicKey: currentPeer.publicKey,
                        allowedIPs: currentPeer.allowedIPs,
                        endpoint: currentPeer.endpoint,
                        persistentKeepalive: currentPeer.persistentKeepalive
                    ))
                    currentPeer = ("", "", nil, nil)
                }
                currentSection = String(trimmed.dropFirst().dropLast())
                continue
            }

            // Parse key = value
            let parts = trimmed.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            let key = parts[0]
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)

            switch currentSection {
            case "Interface":
                switch key.lowercased() {
                case "privatekey":
                    privateKey = value
                case "address":
                    address = value.components(separatedBy: "/").first ?? value
                case "dns":
                    dns = value
                default:
                    break
                }
            case "Peer":
                switch key.lowercased() {
                case "publickey":
                    currentPeer.publicKey = value
                case "allowedips":
                    currentPeer.allowedIPs = value
                case "endpoint":
                    currentPeer.endpoint = value
                case "persistentkeepalive":
                    currentPeer.persistentKeepalive = Int(value)
                default:
                    break
                }
            default:
                break
            }
        }

        // Don't forget the last peer
        if !currentPeer.publicKey.isEmpty {
            peers.append(WireGuardPeerData(
                publicKey: currentPeer.publicKey,
                allowedIPs: currentPeer.allowedIPs,
                endpoint: currentPeer.endpoint,
                persistentKeepalive: currentPeer.persistentKeepalive
            ))
        }

        return WireGuardConfigData(
            privateKey: privateKey,
            address: address,
            dns: dns,
            peers: peers
        )
    }

    func disconnect() async {
        vpnManager?.connection.stopVPNTunnel()
        isConnected = false
        connectedNetwork = nil
        connectedNetworkId = nil
        currentDevice = nil
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

    private func configureVPN(configString: String, networkName: String) async throws {
        guard let manager = vpnManager else { return }

        // Extract endpoint from config for display
        var serverAddress = "ple7.com"
        for line in configString.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed.hasPrefix("endpoint") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    serverAddress = parts[1].trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "com.ple7.vpn.PacketTunnel"
        tunnelProtocol.serverAddress = serverAddress
        tunnelProtocol.providerConfiguration = [:]

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
                    self?.currentDevice = nil
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
