import Foundation
import KeychainAccess

struct EmptyResponse: Decodable {}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError
    case networkError(Error)

    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please sign in again"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to process response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://ple7.com/api"
    private let keychain = Keychain(service: "com.ple7.vpn")
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    var authToken: String? {
        get { try? keychain.get("authToken") }
        set {
            if let token = newValue {
                try? keychain.set(token, key: "authToken")
            } else {
                try? keychain.remove("authToken")
            }
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        let response: AuthResponse = try await post("/auth/login", body: body)
        authToken = response.accessToken
        return response
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        let response: AuthResponse = try await post("/auth/register", body: body)
        authToken = response.accessToken
        return response
    }

    func getCurrentUser() async throws -> User {
        return try await get("/auth/me")
    }

    func logout() {
        authToken = nil
    }

    // MARK: - Networks

    func getNetworks() async throws -> [Network] {
        return try await get("/mesh/networks")
    }

    func getDevices(networkId: String) async throws -> [Device] {
        return try await get("/mesh/networks/\(networkId)/devices")
    }

    func getDeviceConfig(deviceId: String) async throws -> DeviceConfigResponse {
        return try await get("/mesh/devices/\(deviceId)/config")
    }

    func registerDevice(networkId: String, name: String, publicKey: String) async throws -> Device {
        let body: [String: Any] = [
            "name": name,
            "public_key": publicKey,
            "platform": "IOS"
        ]
        return try await post("/mesh/networks/\(networkId)/devices", body: body)
    }

    // MARK: - Auto Register Device

    func autoRegisterDevice(networkId: String, deviceName: String) async throws -> Device {
        let body: [String: Any] = [
            "deviceName": deviceName,
            "platform": "IOS"
        ]
        return try await post("/mesh/networks/\(networkId)/auto-register", body: body)
    }

    // MARK: - Relays

    func getRelays() async throws -> [Relay] {
        return try await get("/mesh/relays")
    }

    // MARK: - Exit Node

    func getExitNode(networkId: String) async throws -> ExitNodeConfig {
        return try await get("/mesh/networks/\(networkId)/exit-node")
    }

    func setExitNode(networkId: String, exitType: String, relayId: String?) async throws -> ExitNodeConfig {
        var body: [String: Any] = ["exit_type": exitType]
        if let relayId = relayId {
            body["exit_relay_id"] = relayId
        }
        return try await patch("/mesh/networks/\(networkId)/exit-node", body: body)
    }

    func setExitNode(networkId: String, type: ExitNodeType, exitId: String?) async throws {
        var body: [String: Any] = ["type": type.rawValue]
        if let exitId = exitId {
            body["id"] = exitId
        }
        let _: EmptyResponse = try await patch("/mesh/networks/\(networkId)/exit-node", body: body)
    }

    // MARK: - User

    func getUser() async throws -> User {
        return try await get("/auth/me")
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        return try await execute(request)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = try makeRequest(path: path, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    private func patch<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = try makeRequest(path: path, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError
            }
        case 401:
            authToken = nil
            throw APIError.unauthorized
        default:
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.message)
            }
            throw APIError.serverError("Request failed with status \(httpResponse.statusCode)")
        }
    }
}
