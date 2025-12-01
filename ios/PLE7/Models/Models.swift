import Foundation

struct Network: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let ipRange: String
    let deviceCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ipRange = "ip_range"
        case deviceCount = "device_count"
    }

    init(id: String, name: String, description: String?, ipRange: String, deviceCount: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.ipRange = ipRange
        self.deviceCount = deviceCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        ipRange = try container.decodeIfPresent(String.self, forKey: .ipRange) ?? "10.100.0.0/27"
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount) ?? 0
    }
}

struct Device: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let ip: String
    let platform: String
    let publicKey: String
    let isExitNode: Bool
    let networkId: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ip = "ip_address"
        case platform
        case publicKey = "public_key"
        case isExitNode = "is_exit_node"
        case networkId = "network_id"
    }

    init(id: String, name: String, ip: String, platform: String, publicKey: String, isExitNode: Bool, networkId: String) {
        self.id = id
        self.name = name
        self.ip = ip
        self.platform = platform
        self.publicKey = publicKey
        self.isExitNode = isExitNode
        self.networkId = networkId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ip = try container.decodeIfPresent(String.self, forKey: .ip) ?? ""
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "UNKNOWN"
        publicKey = try container.decodeIfPresent(String.self, forKey: .publicKey) ?? ""
        isExitNode = try container.decodeIfPresent(Bool.self, forKey: .isExitNode) ?? false
        networkId = try container.decodeIfPresent(String.self, forKey: .networkId) ?? ""
    }
}

struct User: Codable {
    let id: String
    let email: String
    let plan: String
    let emailVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case plan
        case emailVerified = "email_verified"
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

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

/// Response from /api/mesh/devices/:id/config
struct DeviceConfigResponse: Codable {
    let config: String  // WireGuard INI-style config string
    let hasPrivateKey: Bool
    let relay: Relay?

    enum CodingKeys: String, CodingKey {
        case config
        case hasPrivateKey
        case relay
    }
}

struct APIErrorResponse: Codable {
    let message: String
    let statusCode: Int?
}

// MARK: - Relay (PLE7 Infrastructure Exit Nodes)

struct Relay: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let location: String
    let countryCode: String
    let publicEndpoint: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case countryCode = "country_code"
        case publicEndpoint = "public_endpoint"
        case status
    }

    var isOnline: Bool {
        status == "online" || status == "ONLINE"
    }

    var flagEmoji: String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flag = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flag))
            }
        }
        return emoji
    }
}

// MARK: - Exit Node Selection

enum ExitNodeType: String, Codable {
    case none
    case relay
    case device
}

struct ExitNodeSelection: Codable {
    let type: ExitNodeType
    let id: String?
}

// MARK: - Auto Register Response

struct AutoRegisterResponse: Codable {
    let device: Device
    let config: String?

    enum CodingKeys: String, CodingKey {
        case device
        case config
    }
}
