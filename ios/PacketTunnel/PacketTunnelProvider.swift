import NetworkExtension
import WireGuardKit
import KeychainAccess
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var adapter: WireGuardAdapter?
    private let keychain = Keychain(service: "com.ple7.vpn", accessGroup: "group.com.ple7.vpn")
    private let logger = Logger(subsystem: "com.ple7.vpn.PacketTunnel", category: "WireGuard")

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting tunnel...")

        // Load WireGuard config from shared keychain
        guard let configData = try? keychain.getData("wireguardConfig"),
              let wgConfig = try? JSONDecoder().decode(WireGuardConfig.self, from: configData) else {
            logger.error("Failed to load WireGuard config from keychain")
            completionHandler(PacketTunnelError.configurationError)
            return
        }

        // Build WireGuard configuration string
        let configString = buildWireGuardConfig(from: wgConfig)

        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: configString) else {
            logger.error("Failed to parse WireGuard configuration")
            completionHandler(PacketTunnelError.invalidConfiguration)
            return
        }

        // Create adapter and start tunnel
        adapter = WireGuardAdapter(with: self) { [weak self] logLevel, message in
            self?.logger.log(level: logLevel.osLogLevel, "\(message)")
        }

        adapter?.start(tunnelConfiguration: tunnelConfiguration) { [weak self] adapterError in
            if let error = adapterError {
                self?.logger.error("Adapter start failed: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                self?.logger.info("Tunnel started successfully")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping tunnel with reason: \(String(describing: reason))")

        adapter?.stop { [weak self] error in
            if let error = error {
                self?.logger.error("Adapter stop failed: \(error.localizedDescription)")
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from main app
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        logger.info("Received app message: \(message)")

        switch message {
        case "status":
            let status = adapter != nil ? "connected" : "disconnected"
            completionHandler?(status.data(using: .utf8))
        default:
            completionHandler?(nil)
        }
    }

    private func buildWireGuardConfig(from config: WireGuardConfig) -> String {
        var lines: [String] = []

        // Interface section
        lines.append("[Interface]")
        lines.append("PrivateKey = \(config.privateKey)")
        lines.append("Address = \(config.address)")
        if let dns = config.dns, !dns.isEmpty {
            lines.append("DNS = \(dns)")
        }

        // Peer sections
        for peer in config.peers {
            lines.append("")
            lines.append("[Peer]")
            lines.append("PublicKey = \(peer.publicKey)")
            lines.append("AllowedIPs = \(peer.allowedIPs)")
            if let endpoint = peer.endpoint, !endpoint.isEmpty {
                lines.append("Endpoint = \(endpoint)")
            }
            if let keepalive = peer.persistentKeepalive, keepalive > 0 {
                lines.append("PersistentKeepalive = \(keepalive)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Error Types

enum PacketTunnelError: Error {
    case configurationError
    case invalidConfiguration
    case adapterError
}

// MARK: - WireGuard Config Model (shared with main app)

struct WireGuardConfig: Codable {
    let privateKey: String
    let address: String
    let dns: String?
    let peers: [WireGuardPeer]

    enum CodingKeys: String, CodingKey {
        case privateKey = "private_key"
        case address
        case dns
        case peers
    }
}

struct WireGuardPeer: Codable {
    let publicKey: String
    let allowedIPs: String
    let endpoint: String?
    let persistentKeepalive: Int?

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case allowedIPs = "allowed_ips"
        case endpoint
        case persistentKeepalive = "persistent_keepalive"
    }
}

// MARK: - Logger Extension

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
