import Foundation

/// WireGuard configuration data shared between main app and PacketTunnel extension
struct WireGuardConfigData: Codable {
    let privateKey: String
    let address: String
    let dns: String?
    let peers: [WireGuardPeerData]

    enum CodingKeys: String, CodingKey {
        case privateKey = "private_key"
        case address
        case dns
        case peers
    }
}

struct WireGuardPeerData: Codable {
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
