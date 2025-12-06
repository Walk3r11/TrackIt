import Foundation

struct AuthResponse: Decodable {
    let token: String
    let user: UserProfile
}

enum AuthMode: String, CaseIterable, Hashable {
    case login
    case signup
}

enum APIError: Error {
    case invalidURL
    case requestFailed(String)
    case decodingFailed
}

struct APIClient {
    static let shared = APIClient()

    private var baseURL: URL? {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: override) {
            return url
        }
        return URL(string: "https://trackit-dashboard-git-tests-walk3r11s-projects.vercel.app")
    }

    private func issueToken(email: String, password: String) async throws -> String {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password], options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Token request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }
        struct TokenResp: Decodable { let token: String }
        guard let decoded = try? JSONDecoder().decode(TokenResp.self, from: data) else {
            throw APIError.decodingFailed
        }
        return decoded.token
    }

    func authenticate(mode: AuthMode, payload: [String: String]) async throws -> AuthResponse {
        guard let base = baseURL else { throw APIError.invalidURL }
        guard let email = payload["email"], let password = payload["password"] else {
            throw APIError.requestFailed("Missing credentials")
        }

        // get a bearer token
        let bearer = try await issueToken(email: email, password: password)

        // call login/signup with bearer header
        let path = mode == .login ? "/api/auth/login" : "/api/auth/signup"
        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        let body: [String: Any]
        if mode == .signup {
            body = [
                "firstName": payload["firstName"] ?? "",
                "lastName": payload["lastName"] ?? ""
            ]
        } else {
            body = [:]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let auth = try? decoder.decode(AuthResponse.self, from: data) else {
            throw APIError.decodingFailed
        }
        return auth
    }

    func fetchUser(byEmail email: String) async throws -> UserProfile? {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/users/lookup")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "query", value: email)]
        guard let finalURL = components?.url else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: finalURL)
        guard let http = response as? HTTPURLResponse else { throw APIError.requestFailed("No HTTP response") }
        if http.statusCode == 200 {
            struct LookupResponse: Decodable { let user: UserProfile? }
            let decoded = try? JSONDecoder().decode(LookupResponse.self, from: data)
            return decoded?.user
        }
        if http.statusCode == 404 { return nil }
        let message = String(data: data, encoding: .utf8) ?? "Request failed"
        throw APIError.requestFailed("Status \(http.statusCode): \(message)")
    }

    func saveCard(userId: String, card: CardInfo) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/cards")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "userId": userId,
            "nickname": card.nickname,
            "last4": card.last4,
            "fullNumber": card.fullNumber ?? NSNull(),
            "limit": card.limit ?? 0,
            "balance": card.balance ?? 0,
            "tags": card.tags ?? []
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }
    }

    func updateCard(userId: String, card: CardInfo) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/cards")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "id": card.id.uuidString,
            "userId": userId,
            "limit": card.limit ?? 0,
            "balance": card.balance ?? 0,
            "nickname": card.nickname,
            "tags": card.tags ?? [],
            "last4": card.last4,
            "fullNumber": card.fullNumber ?? NSNull()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }
    }

    func deleteCard(userId: String, cardId: UUID) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/cards"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: cardId.uuidString),
            URLQueryItem(name: "userId", value: userId)
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }
    }

    func saveTransaction(userId: String, transaction: Transaction) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/transactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "userId": userId,
            "amount": transaction.amount,
            "category": transaction.category,
            "createdAt": ISO8601DateFormatter().string(from: transaction.date)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }
    }

    func fetchCards(userId: String) async throws -> [CardInfo] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/cards"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }
        struct CardRow: Decodable {
            let id: String
            let nickname: String?
            let last4: String
            let full_number: String?
            let card_limit: Double?
            let balance: Double?
            let tags: [String]?
        }
        struct Resp: Decodable { let cards: [CardRow] }
        guard let decoded = try? JSONDecoder().decode(Resp.self, from: data) else {
            throw APIError.decodingFailed
        }
        return decoded.cards.map {
            CardInfo(
                id: UUID(uuidString: $0.id) ?? UUID(),
                nickname: $0.nickname ?? "",
                fullNumber: $0.full_number,
                last4: $0.last4,
                limit: $0.card_limit,
                balance: $0.balance,
                tags: $0.tags
            )
        }
    }

    func fetchTransactions(userId: String) async throws -> [Transaction] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/transactions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }
        struct TxRow: Decodable {
            let id: String
            let amount: Double
            let category: String
            let created_at: String
        }
        struct Resp: Decodable { let transactions: [TxRow] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(Resp.self, from: data) else { throw APIError.decodingFailed }
        let df = ISO8601DateFormatter()
        return decoded.transactions.map {
            Transaction(
                id: UUID(uuidString: $0.id) ?? UUID(),
                amount: $0.amount,
                category: $0.category,
                date: df.date(from: $0.created_at) ?? .now,
                kind: $0.amount >= 0 ? .income : .expense
            )
        }
    }
}
