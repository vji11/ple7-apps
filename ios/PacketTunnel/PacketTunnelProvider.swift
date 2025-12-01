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
              let wgConfig = try? JSONDecoder().decode(WireGuardConfigData.self, from: configData) else {
            logger.error("Failed to load WireGuard config from keychain")
            completionHandler(PacketTunnelError.configurationError)
            return
        }

        // Build TunnelConfiguration
        guard let tunnelConfiguration = buildTunnelConfiguration(from: wgConfig) else {
            logger.error("Failed to build WireGuard configuration")
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

    private func buildTunnelConfiguration(from config: WireGuardConfigData) -> TunnelConfiguration? {
        // Parse private key
        guard let privateKey = PrivateKey(base64Key: config.privateKey) else {
            logger.error("Invalid private key")
            return nil
        }

        // Build interface configuration
        var interfaceConfig = InterfaceConfiguration(privateKey: privateKey)

        // Parse address
        if let addressRange = IPAddressRange(from: config.address) {
            interfaceConfig.addresses = [addressRange]
        }

        // Parse DNS
        if let dnsString = config.dns, !dnsString.isEmpty {
            let dnsServers = dnsString.split(separator: ",").compactMap { dns -> DNSServer? in
                DNSServer(from: String(dns.trimmingCharacters(in: .whitespaces)))
            }
            interfaceConfig.dns = dnsServers
        }

        // Build peer configurations
        var peerConfigs: [PeerConfiguration] = []
        for peer in config.peers {
            guard let publicKey = PublicKey(base64Key: peer.publicKey) else {
                logger.error("Invalid peer public key")
                continue
            }

            var peerConfig = PeerConfiguration(publicKey: publicKey)

            // Parse allowed IPs
            let allowedIPs = peer.allowedIPs.split(separator: ",").compactMap { ip -> IPAddressRange? in
                IPAddressRange(from: String(ip.trimmingCharacters(in: .whitespaces)))
            }
            peerConfig.allowedIPs = allowedIPs

            // Parse endpoint
            if let endpointString = peer.endpoint, !endpointString.isEmpty {
                peerConfig.endpoint = Endpoint(from: endpointString)
            }

            // Persistent keepalive
            if let keepalive = peer.persistentKeepalive, keepalive > 0 {
                peerConfig.persistentKeepAlive = UInt16(keepalive)
            }

            peerConfigs.append(peerConfig)
        }

        return TunnelConfiguration(name: "PLE7 VPN", interface: interfaceConfig, peers: peerConfigs)
    }
}

// MARK: - Error Types

enum PacketTunnelError: Error {
    case configurationError
    case invalidConfiguration
    case adapterError
}

// WireGuardConfigData and WireGuardPeerData are now in Shared/WireGuardTypes.swift

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
