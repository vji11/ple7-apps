# Claude Development Guidelines - PLE7 iOS App

## Project Overview
Native iOS VPN client for PLE7 mesh networks using SwiftUI and WireGuardKit.

**Bundle IDs:**
- Main app: `com.ple7.vpn`
- Network Extension: `com.ple7.vpn.PacketTunnel`
- App Group: `group.com.ple7.vpn`

**Backend API:** `https://ple7.com/api`

## Project Structure

```
ios/
├── project.yml              # XcodeGen configuration
├── PLE7/                    # Main app target
│   ├── App/PLE7App.swift    # App entry point
│   ├── Views/               # SwiftUI views
│   │   ├── ContentView.swift       # Root view (auth routing)
│   │   ├── LoginView.swift         # Login/Register screen
│   │   ├── MainTabView.swift       # Tab navigation container
│   │   ├── HomeView.swift          # VPN connection screen
│   │   ├── DashboardView.swift     # Devices list
│   │   ├── TopologyView.swift      # Network topology visualization
│   │   ├── AccountView.swift       # User account & settings
│   │   ├── MainView.swift          # (Legacy - replaced by MainTabView)
│   │   └── NetworkDetailView.swift # (Legacy network detail sheet)
│   ├── ViewModels/
│   │   └── NetworksViewModel.swift
│   ├── Services/
│   │   ├── APIClient.swift      # Backend API communication
│   │   ├── AuthManager.swift    # Authentication state
│   │   └── VPNManager.swift     # NEVPNManager wrapper
│   ├── Models/Models.swift      # Data models
│   ├── PLE7.entitlements
│   ├── Info.plist
│   └── Assets.xcassets/
├── PacketTunnel/            # Network Extension target
│   ├── PacketTunnelProvider.swift  # WireGuard tunnel implementation
│   ├── PacketTunnel.entitlements
│   └── Info.plist
└── Shared/                  # Shared code between targets
```

## Quick Commands

```bash
# Generate Xcode project (after any project.yml changes)
xcodegen generate

# Open project
open PLE7.xcodeproj

# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData/PLE7-*
```

## Architecture

### Main App
- **SwiftUI** for UI with **TabView** navigation
- **AppState**: Centralized state management for networks, devices, relays
- **AuthManager**: Handles login/logout, token storage in Keychain
- **VPNManager**: Controls VPN via NEVPNManager, stores config in shared Keychain
- **APIClient**: REST API communication with backend

### Tab Navigation Structure
```
MainTabView
├── HomeView (VPN tab)
│   ├── VPNStatusSection
│   ├── NetworkSelectionSection
│   └── RelaySelectionSection
├── DashboardView (Dashboard tab)
│   ├── NetworkHeaderCard
│   └── DeviceCards
├── TopologyView (Topology tab)
│   ├── Internet node
│   ├── Relay node
│   ├── This device node
│   └── Other devices
└── AccountView (Account tab)
    ├── ProfileCard
    ├── PlanCard
    ├── StatisticsCard
    └── SettingsSection
```

### PacketTunnel Extension
- **NEPacketTunnelProvider** subclass
- Uses **WireGuardKit** for tunnel implementation
- Reads WireGuard config from shared Keychain (App Group)
- Runs as separate process from main app

### Data Flow
```
Main App                          PacketTunnel Extension
    │                                      │
    ├─► APIClient.getDeviceConfig()        │
    │         │                            │
    │         ▼                            │
    ├─► Store in shared Keychain ─────────►│
    │         │                            │
    │         ▼                            │
    ├─► VPNManager.connect()               │
    │         │                            │
    │         ▼                            │
    │   NEVPNManager.startVPNTunnel() ────►│
    │                                      ▼
    │                          PacketTunnelProvider.startTunnel()
    │                                      │
    │                                      ▼
    │                          Read config from Keychain
    │                                      │
    │                                      ▼
    │                          WireGuardAdapter.start()
```

## API Endpoints Used

```
POST /api/auth/login          - Email/password login
POST /api/auth/register       - Create account
GET  /api/auth/me             - Get current user
GET  /api/auth/google/mobile  - Google OAuth (opens in browser)

GET  /api/mesh/networks                    - List networks
GET  /api/mesh/networks/:id/devices        - List devices in network
GET  /api/mesh/devices/:id/config          - Get WireGuard config for device
POST /api/mesh/networks/:id/devices        - Register new device
POST /api/mesh/networks/:id/auto-register  - Auto register iOS device

GET  /api/mesh/relays                      - List available relays
GET  /api/mesh/networks/:id/exit-node      - Get current exit node config
PATCH /api/mesh/networks/:id/exit-node     - Set exit node (relay or device)
```

## Models

```swift
Network: id, name, description, ipRange, deviceCount
Device: id, name, ip, platform, publicKey, isExitNode, networkId
User: id, email, plan, emailVerified
Relay: id, name, location, countryCode, publicEndpoint, status
ExitNodeConfig: exitType, exitRelayId, exitDeviceId, relay
ExitNodeType: none, relay, device
DeviceConfigResponse: config (WireGuard INI string), hasPrivateKey, relay
```

## Dependencies (via Swift Package Manager)

- **WireGuardKit** (github.com/WireGuard/wireguard-apple) - WireGuard implementation
- **KeychainAccess** (github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper

## Entitlements Required

**Main App (PLE7.entitlements):**
- `com.apple.developer.networking.networkextension` → packet-tunnel-provider
- `com.apple.developer.networking.vpn.api` → allow-vpn
- `com.apple.security.application-groups` → group.com.ple7.vpn
- `keychain-access-groups`

**Extension (PacketTunnel.entitlements):**
- `com.apple.developer.networking.networkextension` → packet-tunnel-provider
- `com.apple.security.application-groups` → group.com.ple7.vpn
- `keychain-access-groups`

## Common Tasks

### Add a new View
1. Create SwiftUI view in `PLE7/Views/`
2. Add to appropriate tab in `MainTabView.swift`
3. Use `@EnvironmentObject` for AppState/AuthManager/VPNManager access

### Add API endpoint
1. Add method to `APIClient.swift`
2. Add response model to `Models.swift` if needed
3. Call from AppState or ViewModel

### Modify WireGuard config handling
1. Update `WireGuardConfig` model in both:
   - `PLE7/Models/Models.swift`
   - `PacketTunnel/PacketTunnelProvider.swift`
2. Update `buildWireGuardConfig()` in PacketTunnelProvider

### Debug VPN issues
1. Connect iPhone to Mac
2. Open Console.app
3. Filter by "com.ple7.vpn.PacketTunnel"
4. Check for WireGuard adapter errors

## Build Requirements

- macOS with Xcode 15+
- Go installed (`brew install go`) - required for WireGuardKit
- XcodeGen (`brew install xcodegen`)
- Physical iPhone for testing (VPN doesn't work in simulator)

## Related Repositories

- **Backend/Frontend:** github.com/vji11/ple7 (`/opt/apps/ple7/`)
- **Desktop App:** This repo, `/desktop/` folder

## Current Status

- ✅ Project structure created
- ✅ SwiftUI views (Login, Main, NetworkDetail)
- ✅ Tab navigation with 4 tabs (VPN, Dashboard, Topology, Account)
- ✅ Network selector dropdown
- ✅ Relay/exit location selector
- ✅ Devices list in Dashboard
- ✅ Network topology visualization
- ✅ Account view with plan info
- ✅ API client with auth + relay endpoints
- ✅ VPN manager with NEVPNManager
- ✅ PacketTunnel extension with WireGuardKit
- ⏳ Testing on device
- ⏳ App icon
- ⏳ App Store submission

## Latest Changes (2025-12-05)

### UI Redesign
- Replaced half-grey/half-white screen with full white background
- Added bottom TabView navigation with 4 tabs
- Network selection moved to dropdown picker
- Relay selection added below network picker
- New TopologyView showing visual network diagram
- New AccountView with user info, plan, settings

### Files Added/Modified
- `MainTabView.swift` - New tab navigation container
- `HomeView.swift` - New VPN connection screen
- `DashboardView.swift` - New devices list view
- `TopologyView.swift` - New topology visualization
- `AccountView.swift` - New account/settings view
- `ContentView.swift` - Updated to use MainTabView
- `Models.swift` - Added Relay, ExitNodeConfig, ExitNodeType models
- `APIClient.swift` - Added relay and exit node API methods
