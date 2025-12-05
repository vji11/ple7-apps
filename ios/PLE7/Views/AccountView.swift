import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var viewModel = AccountViewModel()
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Card
                    ProfileCard(user: viewModel.user)

                    // Plan Section
                    PlanCard(user: viewModel.user)

                    // Statistics Section
                    StatisticsCard()

                    // Settings Section
                    SettingsSection(showingLogoutAlert: $showingLogoutAlert)

                    // App Info
                    AppInfoSection()
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Account")
            .onAppear {
                viewModel.loadUser()
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct ProfileCard: View {
    let user: User?

    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                Text(initials)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }

            // Email
            VStack(spacing: 4) {
                Text(user?.email ?? "Loading...")
                    .font(.headline)

                if let user = user {
                    HStack(spacing: 4) {
                        if user.emailVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Not verified")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var initials: String {
        guard let email = user?.email else { return "?" }
        let name = email.components(separatedBy: "@").first ?? email
        return String(name.prefix(2)).uppercased()
    }
}

struct PlanCard: View {
    let user: User?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Plan")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(planDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(planBadge)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(planColor.opacity(0.15))
                    .foregroundColor(planColor)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var planName: String {
        switch user?.plan {
        case "BASIC": return "Basic"
        case "ADVANCED": return "Advanced"
        default: return "Free"
        }
    }

    private var planDescription: String {
        switch user?.plan {
        case "BASIC": return "3 networks, 10 devices"
        case "ADVANCED": return "10 networks, 100 devices"
        default: return "1 network, 2 devices"
        }
    }

    private var planBadge: String {
        switch user?.plan {
        case "BASIC": return "BASIC"
        case "ADVANCED": return "PRO"
        default: return "FREE"
        }
    }

    private var planColor: Color {
        switch user?.plan {
        case "BASIC": return .blue
        case "ADVANCED": return .purple
        default: return .gray
        }
    }
}

struct StatisticsCard: View {
    @EnvironmentObject var vpnManager: VPNManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Session")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                StatItem(
                    icon: "clock.fill",
                    title: "Connected",
                    value: vpnManager.isConnected ? "Active" : "--",
                    color: vpnManager.isConnected ? .green : .gray
                )

                Divider()
                    .frame(height: 40)

                StatItem(
                    icon: "network",
                    title: "Network",
                    value: vpnManager.connectedNetwork ?? "--",
                    color: .accentColor
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection: View {
    @Binding var showingLogoutAlert: Bool

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "globe",
                title: "Manage Account",
                subtitle: "Visit ple7.com"
            ) {
                if let url = URL(string: "https://ple7.com/account") {
                    UIApplication.shared.open(url)
                }
            }

            Divider()
                .padding(.leading, 52)

            SettingsRow(
                icon: "questionmark.circle",
                title: "Help & Support",
                subtitle: "Get help"
            ) {
                if let url = URL(string: "https://ple7.com/support") {
                    UIApplication.shared.open(url)
                }
            }

            Divider()
                .padding(.leading, 52)

            SettingsRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Sign Out",
                subtitle: nil,
                isDestructive: true
            ) {
                showingLogoutAlert = true
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isDestructive ? .red : .primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppInfoSection: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("PLE7 VPN")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Version \(appVersion)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

@MainActor
class AccountViewModel: ObservableObject {
    @Published var user: User?

    func loadUser() {
        Task {
            do {
                user = try await APIClient.shared.getUser()
            } catch {
                print("Failed to load user: \(error)")
            }
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthManager.shared)
        .environmentObject(VPNManager.shared)
}
