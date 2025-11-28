# PLE7 VPN Apps

Cross-platform VPN client applications for the PLE7 Mesh VPN service.

## Platforms

| Platform | Status | Technology |
|----------|--------|------------|
| Windows | ✅ Available | Tauri + Rust |
| macOS | ✅ Available | Tauri + Rust |
| Linux | ✅ Available | Tauri + Rust |
| iOS | 🚧 Coming Soon | Swift + NetworkExtension |
| Android | 🚧 Coming Soon | Kotlin + VpnService |

## Downloads

Download the latest release for your platform from the [Releases](https://github.com/vji11/ple7-apps/releases) page.

### Desktop

- **Windows**: Download the `.msi` installer
- **macOS (Apple Silicon)**: Download the `aarch64.dmg` file
- **macOS (Intel)**: Download the `x64.dmg` file
- **Linux**: Download the `.deb` (Debian/Ubuntu) or `.AppImage`

## Building from Source

### Desktop (Tauri)

```bash
cd desktop
npm install
npm run tauri build
```

Requirements:
- Node.js 20+
- Rust 1.70+
- Platform-specific dependencies (see [Tauri prerequisites](https://tauri.app/v1/guides/getting-started/prerequisites))

## License

Copyright © 2024 PLE7. All rights reserved.
