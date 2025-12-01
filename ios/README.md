# PLE7 iOS App

Native iOS VPN client for PLE7 mesh networks.

## Requirements

- macOS with Xcode 15+
- Apple Developer account with:
  - Network Extensions capability
  - Personal VPN capability
  - App Groups capability
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation
- Go (for WireGuardKit)

## Setup

### 1. Install Dependencies

```bash
brew install xcodegen go
```

### 2. Generate Xcode Project

```bash
cd ios
xcodegen generate
```

### 3. Configure Signing

1. Open `PLE7.xcodeproj` in Xcode
2. Select the **PLE7** target
3. In **Signing & Capabilities**:
   - Select your Team
   - Set Bundle Identifier: `com.ple7.vpn`
4. Select the **PacketTunnel** target
5. In **Signing & Capabilities**:
   - Select your Team
   - Set Bundle Identifier: `com.ple7.vpn.PacketTunnel`

### 4. Build & Run

1. Connect your iPhone
2. Select your device in Xcode
3. Press **Cmd+R** to build and run

## Project Structure

```
ios/
├── project.yml           # XcodeGen configuration
├── PLE7/                 # Main app target
│   ├── App/              # App entry point
│   ├── Views/            # SwiftUI views
│   ├── ViewModels/       # View models
│   ├── Services/         # API client, VPN manager
│   ├── Models/           # Data models
│   └── Assets.xcassets/  # App icons, colors
├── PacketTunnel/         # Network Extension target
│   └── PacketTunnelProvider.swift
└── Shared/               # Shared code between targets
```

## Features

- Email/password authentication
- Google Sign-In
- View and select mesh networks
- Connect/disconnect VPN
- WireGuard-based tunneling
- System VPN integration

## Architecture

- **Main App**: SwiftUI interface for authentication and network management
- **PacketTunnel Extension**: Network Extension that handles the actual VPN tunnel using WireGuardKit
- **Shared Keychain**: Used to pass WireGuard configuration from app to extension

## Dependencies

- [WireGuardKit](https://github.com/WireGuard/wireguard-apple) - WireGuard implementation
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper

## Troubleshooting

### "Network Extension entitlement missing"

Make sure your Apple Developer account has the Network Extension capability enabled for both bundle IDs.

### VPN won't connect

1. Check that the PacketTunnel extension is properly signed
2. Verify the App Group is correctly configured
3. Check device logs in Console.app for errors

### Build errors with WireGuardKit

WireGuardKit requires Go to be installed for building the WireGuard Go library:

```bash
brew install go
```
