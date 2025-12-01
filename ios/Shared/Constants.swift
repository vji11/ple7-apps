import Foundation

/// Shared constants between main app and PacketTunnel extension
enum Constants {
    /// App Group identifier for shared data
    static let appGroup = "group.com.ple7.vpn"

    /// Keychain service name
    static let keychainService = "com.ple7.vpn"

    /// Key for storing WireGuard config in keychain
    static let wireguardConfigKey = "wireguard-config"

    /// Key for storing auth token in keychain
    static let authTokenKey = "auth-token"
}
