import Foundation
import AuthenticationServices
import KeychainAccess

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false

    private let keychain = Keychain(service: "com.ple7.vpn")
    private var webAuthSession: ASWebAuthenticationSession?

    override private init() {
        super.init()
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if APIClient.shared.authToken != nil {
            isLoading = true
            Task {
                do {
                    let user = try await APIClient.shared.getCurrentUser()
                    self.currentUser = user
                    self.isAuthenticated = true
                } catch {
                    // Token invalid, clear it
                    APIClient.shared.authToken = nil
                    self.isAuthenticated = false
                }
                self.isLoading = false
            }
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(email: email, password: password)
        currentUser = response.user
        isAuthenticated = true
    }

    func register(email: String, password: String) async throws {
        let response = try await APIClient.shared.register(email: email, password: password)
        currentUser = response.user
        isAuthenticated = true
    }

    func signInWithGoogle() async throws {
        let authURL = URL(string: "https://ple7.com/api/auth/google/mobile")!
        let callbackScheme = "ple7"

        return try await withCheckedThrowingContinuation { continuation in
            webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                    continuation.resume(throwing: APIError.invalidResponse)
                    return
                }

                Task { @MainActor in
                    APIClient.shared.authToken = token
                    do {
                        let user = try await APIClient.shared.getCurrentUser()
                        self?.currentUser = user
                        self?.isAuthenticated = true
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = false
            webAuthSession?.start()
        }
    }

    func logout() {
        APIClient.shared.logout()
        currentUser = nil
        isAuthenticated = false

        // Also disconnect VPN
        Task {
            await VPNManager.shared.disconnect()
        }
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
