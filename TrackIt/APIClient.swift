import Foundation

struct AuthResponse: Decodable {
    let token: String
    let user: UserProfile
}

struct SessionResponse: Decodable {
    let ok: Bool
    let user: UserProfile?
}

enum AuthMode: String, CaseIterable, Hashable {
    case login
    case signup
}

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .requestFailed(let message):
            return message
        case .decodingFailed:
            return "Failed to decode response"
        }
    }
}

struct APIClient {
    static let shared = APIClient()

    private var baseURL: URL? {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: override) {
            return url
        }
        return URL(string: "https://trackit-dashboard-beryl.vercel.app")
    }

    private func validateHTTP(_ response: URLResponse, data: Data, allowEmptyBody: Bool = false) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.requestFailed("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }
        if !allowEmptyBody && data.isEmpty {
            throw APIError.requestFailed("Empty response body")
        }
    }

    private func postJSON(path: String, body: [String: Any], allowEmptyBody: Bool = false) async throws -> Data {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: allowEmptyBody)
        return data
    }

    private func issueToken(email: String, password: String) async throws -> String {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password], options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("No HTTP response")
        }

        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Token request failed"
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }

        guard !data.isEmpty else {
            throw APIError.requestFailed("Empty token response")
        }

        if let responseString = String(data: data, encoding: .utf8) {
            let lowercased = responseString.lowercased()
            if lowercased.contains("\"error\"") ||
               (lowercased.contains("\"message\"") && (lowercased.contains("invalid") || lowercased.contains("incorrect") || lowercased.contains("wrong") || lowercased.contains("unauthorized") || lowercased.contains("failed"))) {
                throw APIError.requestFailed("Authentication failed: Invalid credentials")
            }
        }

        struct TokenResp: Decodable { let token: String }
        guard let decoded = try? JSONDecoder().decode(TokenResp.self, from: data) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw APIError.requestFailed("Authentication failed: \(errorString)")
            }
            throw APIError.decodingFailed
        }

        guard !decoded.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.requestFailed("Authentication failed: Empty token received")
        }

        return decoded.token
    }

    func authenticate(mode: AuthMode, payload: [String: String]) async throws -> AuthResponse {
        guard let base = baseURL else { throw APIError.invalidURL }
        guard let email = payload["email"], let password = payload["password"] else {
            throw APIError.requestFailed("Missing credentials")
        }

        let bearer = try await issueToken(email: email, password: password)

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
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("No HTTP response")
        }

        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            if http.statusCode == 403 && message.localizedCaseInsensitiveContains("Email not verified") {
                throw APIError.requestFailed("Email not verified")
            }
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }

        guard !data.isEmpty else {
            throw APIError.requestFailed("Empty authentication response")
        }

        if let responseString = String(data: data, encoding: .utf8) {
            let lowercased = responseString.lowercased()
            if lowercased.contains("\"error\"") || lowercased.contains("\"message\"") && (lowercased.contains("invalid") || lowercased.contains("incorrect") || lowercased.contains("wrong") || lowercased.contains("unauthorized") || lowercased.contains("failed")) {
                throw APIError.requestFailed("Authentication failed: Invalid credentials")
            }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let auth = try? decoder.decode(AuthResponse.self, from: data) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw APIError.requestFailed("Authentication failed: \(errorString)")
            }
            throw APIError.decodingFailed
        }

        guard !auth.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.requestFailed("Authentication failed: Empty token received")
        }
        guard !auth.user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.requestFailed("Authentication failed: Invalid user data")
        }

        return auth
    }

    func requestVerification(email: String) async throws {
        _ = try await postJSON(path: "/api/auth/verification/request", body: ["email": email], allowEmptyBody: true)
    }

    func confirmVerification(email: String, code: String) async throws {
        _ = try await postJSON(path: "/api/auth/verification/confirm", body: ["email": email, "code": code], allowEmptyBody: true)
    }

    func requestPasswordReset(email: String) async throws {
        _ = try await postJSON(path: "/api/auth/password/reset/request", body: ["email": email], allowEmptyBody: true)
    }

    func confirmPasswordReset(email: String, token: String, newPassword: String) async throws {
        _ = try await postJSON(
            path: "/api/auth/password/reset/confirm",
            body: ["email": email, "token": token, "newPassword": newPassword],
            allowEmptyBody: true
        )
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

    func validateSession(token: String) async throws -> UserProfile {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/auth/session")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        do {
            try validateHTTP(response, data: data, allowEmptyBody: false)
        } catch {
            throw error
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(SessionResponse.self, from: data),
              decoded.ok,
              let user = decoded.user else {
            throw APIError.decodingFailed
        }
        return user
    }

    func saveCard(userId: String, card: CardInfo) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/cards")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let legacy = card.legacyLimitForAPI()
        var body: [String: Any] = [
            "id": card.id.uuidString,
            "userId": userId,
            "nickname": card.nickname,
            "balance": card.balance ?? 0,
            "tags": card.tags ?? []
        ]
        if let daily = card.dailyLimit { body["dailyLimit"] = daily }
        if let weekly = card.weeklyLimit { body["weeklyLimit"] = weekly }
        if let monthly = card.monthlyLimit { body["monthlyLimit"] = monthly }
        if let limit = legacy.limit { body["limit"] = limit }
        if let period = legacy.period { body["limitPeriod"] = period.rawValue }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    func updateCard(userId: String, card: CardInfo) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/cards")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let legacy = card.legacyLimitForAPI()
        var body: [String: Any] = [
            "id": card.id.uuidString,
            "userId": userId,
            "balance": card.balance ?? 0,
            "nickname": card.nickname,
            "tags": card.tags ?? []
        ]
        if let daily = card.dailyLimit { body["dailyLimit"] = daily }
        if let weekly = card.weeklyLimit { body["weeklyLimit"] = weekly }
        if let monthly = card.monthlyLimit { body["monthlyLimit"] = monthly }
        if let limit = legacy.limit { body["limit"] = limit }
        if let period = legacy.period { body["limitPeriod"] = period.rawValue }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: true)
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
        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    func deleteAccount(userId: String) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/auth/delete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["userId": userId], options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    func saveTransaction(userId: String, transaction: Transaction) async throws {
        let timestamp = ISO8601DateFormatter().string(from: transaction.date)
        let id = transaction.id.uuidString
        guard let cardId = transaction.cardId?.uuidString else {
            throw APIError.requestFailed("Missing cardId")
        }

        let bodies: [[String: Any]] = [
            [
                "id": id,
                "userId": userId,
                "cardId": cardId,
                "amount": transaction.amount,
                "category": transaction.category,
                "categoryName": transaction.category,
                "createdAt": timestamp
            ],
            [
                "id": id,
                "userId": userId,
                "card_id": cardId,
                "amount": transaction.amount,
                "category": transaction.category,
                "categoryName": transaction.category,
                "created_at": timestamp
            ],
            [
                "userId": userId,
                "card_id": cardId,
                "amount": transaction.amount,
                "category": transaction.category,
                "categoryName": transaction.category,
                "created_at": timestamp
            ]
        ]

        var lastError: Error?
        for (idx, body) in bodies.enumerated() {
            do {
                try await postTransactionWithRetry(body: body)
                return
            } catch {
                lastError = error
                if idx == bodies.count - 1 { break }
                if case APIError.requestFailed(let message) = error, message.contains("Status 500") {
                    continue
                }
                break
            }
        }
        throw lastError ?? APIError.requestFailed("Unknown transaction save failure")
    }

    private func postTransaction(body: [String: Any]) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/transactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    private func postTransactionWithRetry(body: [String: Any]) async throws {
        let maxAttempts = 5
        var attempt = 0
        var lastError: Error?

        while attempt < maxAttempts {
            do {
                try await postTransaction(body: body)
                return
            } catch {
                lastError = error
                if case APIError.requestFailed(let message) = error {
                    let shouldRetry = message.contains("Status 409") || message.contains("Status 500")
                    if shouldRetry && attempt < maxAttempts - 1 {
                        let delayMs = [200, 450, 900, 1400][min(attempt, 3)]
                        try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                        attempt += 1
                        continue
                    }
                }
                break
            }
        }

        throw lastError ?? APIError.requestFailed("Transaction save failed")
    }

    func fetchCards(userId: String, token: String? = nil) async throws -> [CardInfo] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/cards"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }
        struct CardRow: Decodable {
            let id: String
            let nickname: String?
            let limit: Double?
            let dailyLimit: Double?
            let weeklyLimit: Double?
            let monthlyLimit: Double?
            let balance: Double?
            let tags: [String]?

            enum CodingKeys: String, CodingKey {
                case id
                case nickname
                case limit
                case card_limit
                case cardLimit
                case dailyLimit
                case daily_limit
                case weeklyLimit
                case weekly_limit
                case monthlyLimit
                case monthly_limit
                case balance
                case card_balance
                case tags
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
                limit = Self.decodeNumber(from: container, keys: [.limit, .card_limit, .cardLimit])
                dailyLimit = Self.decodeNumber(from: container, keys: [.dailyLimit, .daily_limit])
                weeklyLimit = Self.decodeNumber(from: container, keys: [.weeklyLimit, .weekly_limit])
                monthlyLimit = Self.decodeNumber(from: container, keys: [.monthlyLimit, .monthly_limit])
                balance = Self.decodeNumber(from: container, keys: [.balance, .card_balance])
                if let array = try? container.decodeIfPresent([String].self, forKey: .tags) {
                    tags = array
                } else if let string = try? container.decodeIfPresent(String.self, forKey: .tags) {
                    tags = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                } else {
                    tags = nil
                }
            }

            private static func decodeNumber(from container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> Double? {
                for key in keys {
                    if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
                        return double
                    }
                    if let string = try? container.decodeIfPresent(String.self, forKey: key) {
                        if let parsed = Double(string) { return parsed }
                        if let number = NumberFormatter().number(from: string) { return number.doubleValue }
                    }
                }
                return nil
            }
        }

        struct Resp: Decodable { let cards: [CardRow] }
        struct AltResp: Decodable { let data: [CardRow] }
        let decoder = JSONDecoder()
        let rows: [CardRow]
        if let decoded = try? decoder.decode(Resp.self, from: data) {
            rows = decoded.cards
        } else if let decoded = try? decoder.decode(AltResp.self, from: data) {
            rows = decoded.data
        } else if let decoded = try? decoder.decode([CardRow].self, from: data) {
            rows = decoded
        } else {
            throw APIError.decodingFailed
        }

        return rows.map {
            let parsedDaily = ($0.dailyLimit ?? 0) > 0 ? $0.dailyLimit : nil
            let parsedWeekly = ($0.weeklyLimit ?? 0) > 0 ? $0.weeklyLimit : nil
            let parsedMonthly = ($0.monthlyLimit ?? 0) > 0 ? $0.monthlyLimit : nil
            let parsedLegacyMonthly = ($0.limit ?? 0) > 0 ? $0.limit : nil

            let primary: (SpendingLimitPeriod, Double)?
            if let d = parsedDaily { primary = (.daily, d) }
            else if let w = parsedWeekly { primary = (.weekly, w) }
            else if let m = parsedMonthly { primary = (.monthly, m) }
            else if let m = parsedLegacyMonthly { primary = (.monthly, m) }
            else { primary = nil }

            return CardInfo(
                id: UUID(uuidString: $0.id) ?? UUID(),
                nickname: $0.nickname ?? "",
                limit: primary?.1,
                limitPeriod: primary?.0,
                dailyLimit: parsedDaily,
                weeklyLimit: parsedWeekly,
                monthlyLimit: parsedMonthly ?? parsedLegacyMonthly,
                balance: $0.balance,
                tags: $0.tags
            )
        }
    }

    func fetchTransactions(userId: String, token: String? = nil) async throws -> [Transaction] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/transactions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        print("[APIClient] fetchTransactions: URL: \(url.absoluteString), hasToken: \(token != nil)")

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[APIClient] ❌ fetchTransactions failed: Status \(statusCode), Message: \(message.prefix(200))")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[APIClient] Full response: \(responseString)")
            }
            throw APIError.requestFailed("Status \(statusCode): \(message)")
        }

        print("[APIClient] ✅ fetchTransactions: Got response, data size: \(data.count) bytes")
        struct TxRow: Decodable {
            let id: String
            let userId: String?
            let cardId: String?
            let amount: Double
            let category: String
            let createdAt: String

            enum CodingKeys: String, CodingKey {
                case id
                case userId
                case user_id
                case cardId
                case card_id
                case amount
                case category
                case categoryName
                case category_name
                case createdAt
                case created_at
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                userId = try container.decodeIfPresent(String.self, forKey: .userId)
                    ?? container.decodeIfPresent(String.self, forKey: .user_id)
                cardId = try container.decodeIfPresent(String.self, forKey: .cardId)
                    ?? container.decodeIfPresent(String.self, forKey: .card_id)

                if let amountNumber = try? container.decode(Double.self, forKey: .amount) {
                    amount = amountNumber
                } else if let amountString = try? container.decode(String.self, forKey: .amount),
                          let amountNumber = Double(amountString) {
                    amount = amountNumber
                } else {
                    amount = 0
                }

                category = try container.decodeIfPresent(String.self, forKey: .category)
                    ?? container.decodeIfPresent(String.self, forKey: .categoryName)
                    ?? container.decodeIfPresent(String.self, forKey: .category_name)
                    ?? ""
                createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
                    ?? container.decodeIfPresent(String.self, forKey: .created_at)
                    ?? ""
            }
        }
        struct Resp: Decodable { let transactions: [TxRow] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys

        if let responseString = String(data: data, encoding: .utf8) {
            print("[APIClient] fetchTransactions raw response: \(responseString.prefix(1000))")
        }

        guard let decoded = try? decoder.decode(Resp.self, from: data) else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("[APIClient] ❌ fetchTransactions decode failed. Response: \(responseString.prefix(500))")
            }
            throw APIError.decodingFailed
        }

        print("[APIClient] ✅ fetchTransactions decoded: \(decoded.transactions.count) transactions")

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return decoded.transactions.map { row in
            let parsedDate = df.date(from: row.createdAt) ?? ISO8601DateFormatter().date(from: row.createdAt) ?? .now
            print("[APIClient] Parsed date: \(row.createdAt) -> \(parsedDate)")
            return Transaction(
                id: UUID(uuidString: row.id) ?? UUID(),
                cardId: row.cardId.flatMap { UUID(uuidString: $0) },
                amount: row.amount,
                category: row.category,
                date: parsedDate,
                kind: row.amount >= 0 ? .income : .expense
            )
        }
    }

    func fetchCategories(userId: String, token: String? = nil) async throws -> [String] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/categories"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        struct CategoryRow: Decodable { let name: String }
        struct Resp: Decodable { let categories: [CategoryRow] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(Resp.self, from: data) else { throw APIError.decodingFailed }
        return decoded.categories
            .map(\.name)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .filter { $0.caseInsensitiveCompare("Uncategorized") != .orderedSame }
    }

    func createCategory(userId: String, name: String) async throws -> [String] {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/categories")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["userId": userId, "name": name], options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        struct CategoryRow: Decodable { let name: String }
        struct Resp: Decodable { let categories: [CategoryRow] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(Resp.self, from: data) else { throw APIError.decodingFailed }
        return decoded.categories
            .map(\.name)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .filter { $0.caseInsensitiveCompare("Uncategorized") != .orderedSame }
    }

    func clearCategories(userId: String) async throws -> [String] {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/categories")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["userId": userId], options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        struct CategoryRow: Decodable { let name: String }
        struct Resp: Decodable { let categories: [CategoryRow] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(Resp.self, from: data) else { throw APIError.decodingFailed }
        return decoded.categories
            .map(\.name)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .filter { $0.caseInsensitiveCompare("Uncategorized") != .orderedSame }
    }

    func fetchSavingsGoal(userId: String, token: String? = nil) async throws -> (goalAmount: Double, goalPeriod: SpendingLimitPeriod) {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/savings"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        struct Goal: Decodable {
            let goalAmount: Double
            let goalPeriod: String
        }
        struct Resp: Decodable { let goal: Goal }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(Resp.self, from: data) else { throw APIError.decodingFailed }
        let period = SpendingLimitPeriod(rawValue: decoded.goal.goalPeriod) ?? .monthly
        return (decoded.goal.goalAmount, period)
    }

    func updateSavingsGoal(userId: String, goalAmount: Double?, goalPeriod: SpendingLimitPeriod?) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/savings")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["userId": userId]
        if let goalAmount { body["goalAmount"] = goalAmount }
        if let goalPeriod { body["goalPeriod"] = goalPeriod.rawValue }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    // MARK: - Groq AI

    struct GroqMessage: Codable {
        let role: String
        let content: String
    }

    struct GroqResponse: Decodable {
        let id: String?
        let choices: [GroqChoice]
        let usage: GroqUsage?
    }

    struct GroqChoice: Decodable {
        let message: GroqMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct GroqUsage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    func chatWithGroq(token: String, messages: [GroqMessage]) async throws -> String {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/groq")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "model": "openai/gpt-oss-120b",
            "temperature": 1,
            "max_completion_tokens": 8192,
            "top_p": 1,
            "reasoning_effort": "medium",
            "stream": true,
            "stop": NSNull()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let groqResponse = try? decoder.decode(GroqResponse.self, from: data),
              let firstChoice = groqResponse.choices.first else {
            throw APIError.decodingFailed
        }

        return firstChoice.message.content
    }

    func chatWithGroqStreaming(token: String, messages: [GroqMessage], userId: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let base = baseURL else {
                    continuation.finish(throwing: APIError.invalidURL)
                    return
                }

                let url = base.appendingPathComponent("/api/groq")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let systemMessage: [[String: String]] = [
                    ["role": "system", "content": "You are a helpful financial assistant. Keep your responses concise and to the point. Focus on actionable advice and key insights. Avoid unnecessary elaboration."]
                ]

                let allMessages = systemMessage + messages.map { ["role": $0.role, "content": $0.content] }

                let body: [String: Any] = [
                    "messages": allMessages,
                    "model": "openai/gpt-oss-120b",
                    "temperature": 1,
                    "max_completion_tokens": 4096,
                    "top_p": 1,
                    "reasoning_effort": "medium",
                    "stream": true,
                    "stop": NSNull(),
                    "userId": userId
                ]

                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.requestFailed("Invalid HTTP response"))
                        return
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                        }
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.finish(throwing: APIError.requestFailed("Status \(httpResponse.statusCode): \(errorMessage)"))
                        return
                    }

                    var buffer = Data()
                    for try await byte in asyncBytes {
                        buffer.append(byte)

                        if let text = String(data: buffer, encoding: .utf8) {
                            let lines = text.components(separatedBy: "\n")
                            if lines.count > 1 {
                                buffer = (lines.last?.data(using: .utf8) ?? Data())

                                for line in lines.dropLast() {
                                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { continue }

                                    if trimmed.hasPrefix("data: ") {
                                        let data = String(trimmed.dropFirst(6))
                                        if data == "[DONE]" {
                                            continuation.finish()
                                            return
                                        }

                                        guard let jsonData = data.data(using: .utf8) else { continue }

                                let decoder = JSONDecoder()
                                decoder.keyDecodingStrategy = .convertFromSnakeCase
                                if let parsed = try? decoder.decode(GroqStreamChunk.self, from: jsonData),
                                   let content = parsed.choices.first?.delta.content,
                                   !content.isEmpty {
                                    continuation.yield(content)
                                }
                                    }
                                }
                            }
                        }
                    }

                    if !buffer.isEmpty, let text = String(data: buffer, encoding: .utf8) {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && trimmed.hasPrefix("data: ") {
                            let data = String(trimmed.dropFirst(6))
                            if data != "[DONE]", let jsonData = data.data(using: .utf8) {
                                let decoder = JSONDecoder()
                                decoder.keyDecodingStrategy = .convertFromSnakeCase
                                if let parsed = try? decoder.decode(GroqStreamChunk.self, from: jsonData),
                                   let content = parsed.choices.first?.delta.content,
                                   !content.isEmpty {
                                    continuation.yield(content)
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    struct GroqStreamChunk: Decodable {
        let choices: [GroqStreamChoice]
    }

    struct GroqStreamChoice: Decodable {
        let delta: GroqStreamDelta
    }

    struct GroqStreamDelta: Decodable {
        let content: String?
    }

    func createTicket(userId: String, subject: String, initialMessage: String, token: String) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/tickets")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "userId": userId,
            "subject": subject,
            "status": "open",
            "initialMessage": initialMessage
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 500 {
                if let responseString = String(data: data, encoding: .utf8),
                   let jsonData = responseString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let ticketId = json["ticketId"] as? String, !ticketId.isEmpty {
                    print("[APIClient] ✅ Ticket created successfully (ticketId: \(ticketId)) despite 500 response")
                    return
                }
            }
        }

        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    func fetchTickets(userId: String, token: String? = nil) async throws -> [SupportTicket] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/tickets"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        print("[APIClient] fetchTickets: URL: \(url.absoluteString), hasToken: \(token != nil)")

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed("No HTTP response")
        }

        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            print("[APIClient] ❌ fetchTickets failed: Status \(http.statusCode), Message: \(message.prefix(200))")
            if http.statusCode == 401 {
                if let token = token {
                    print("[APIClient] ⚠️ Tickets authentication failed. Token length: \(token.count), Token prefix: \(token.prefix(20))...")
                } else {
                    print("[APIClient] ⚠️ No token provided for tickets request")
                }
                print("[APIClient] ⚠️ Tickets require valid authentication, returning empty array")
                return []
            }
            throw APIError.requestFailed("Status \(http.statusCode): \(message)")
        }

        print("[APIClient] ✅ fetchTickets: Got response, data size: \(data.count) bytes")
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }

        struct TicketRow: Decodable {
            let id: String
            let subject: String
            let status: String
            let updatedAt: String?
            let updated_at: String?

            enum CodingKeys: String, CodingKey {
                case id, subject, status
                case updatedAt, updated_at
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                subject = try container.decode(String.self, forKey: .subject)
                status = try container.decode(String.self, forKey: .status)
                updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
                updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
            }
        }
        struct Resp: Decodable { let tickets: [TicketRow] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        guard let decoded = try? decoder.decode(Resp.self, from: data) else {
            let fallbackDecoder = JSONDecoder()
            fallbackDecoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let fallbackDecoded = try? fallbackDecoder.decode(Resp.self, from: data) else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[APIClient] ❌ fetchTickets decode failed. Response: \(responseString.prefix(500))")
                }
                throw APIError.decodingFailed
            }
            return fallbackDecoded.tickets.map { row in
                let status = SupportTicket.Status(rawValue: row.status.lowercased()) ?? .open
                return SupportTicket(
                    id: UUID(uuidString: row.id) ?? UUID(),
                    subject: row.subject,
                    detail: "",
                    status: status
                )
            }
        }

        return decoded.tickets.map { row in
            let status = SupportTicket.Status(rawValue: row.status.lowercased()) ?? .open
            return SupportTicket(
                id: UUID(uuidString: row.id) ?? UUID(),
                subject: row.subject,
                detail: "",
                status: status
            )
        }
    }

    struct TicketMessage: Codable, Identifiable {
        let id: String
        let ticketId: String
        let userId: String?
        let senderType: String
        let content: String
        let createdAt: String
        let readByUserAt: String?
        let readBySupportAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case ticketId
            case ticket_id
            case userId
            case user_id
            case senderType
            case sender_type
            case content
            case createdAt
            case created_at
            case readByUserAt
            case read_by_user_at
            case readBySupportAt
            case read_by_support_at
        }

        init(
            id: String,
            ticketId: String,
            userId: String?,
            senderType: String,
            content: String,
            createdAt: String,
            readByUserAt: String? = nil,
            readBySupportAt: String? = nil
        ) {
            self.id = id
            self.ticketId = ticketId
            self.userId = userId
            self.senderType = senderType
            self.content = content
            self.createdAt = createdAt
            self.readByUserAt = readByUserAt
            self.readBySupportAt = readBySupportAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            ticketId = try container.decodeIfPresent(String.self, forKey: .ticketId)
                ?? container.decode(String.self, forKey: .ticket_id)
            userId = try container.decodeIfPresent(String.self, forKey: .userId)
                ?? container.decodeIfPresent(String.self, forKey: .user_id)
            senderType = try container.decodeIfPresent(String.self, forKey: .senderType)
                ?? container.decode(String.self, forKey: .sender_type)
            content = try container.decode(String.self, forKey: .content)
            createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
                ?? container.decode(String.self, forKey: .created_at)
            readByUserAt = try container.decodeIfPresent(String.self, forKey: .readByUserAt)
                ?? container.decodeIfPresent(String.self, forKey: .read_by_user_at)
            readBySupportAt = try container.decodeIfPresent(String.self, forKey: .readBySupportAt)
                ?? container.decodeIfPresent(String.self, forKey: .read_by_support_at)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(ticketId, forKey: .ticketId)
            try container.encodeIfPresent(userId, forKey: .userId)
            try container.encode(senderType, forKey: .senderType)
            try container.encode(content, forKey: .content)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(readByUserAt, forKey: .readByUserAt)
            try container.encodeIfPresent(readBySupportAt, forKey: .readBySupportAt)
        }
    }

    func fetchTicketMessages(ticketId: String, token: String) async throws -> [TicketMessage] {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/tickets/\(ticketId)/messages")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }

        struct Resp: Decodable { let messages: [TicketMessage] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        guard let decoded = try? decoder.decode(Resp.self, from: data) else {
            let fallbackDecoder = JSONDecoder()
            fallbackDecoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let fallbackDecoded = try? fallbackDecoder.decode(Resp.self, from: data) else {
                throw APIError.decodingFailed
            }
            return fallbackDecoded.messages
        }
        return decoded.messages
    }

    func sendTicketMessage(ticketId: String, content: String, token: String) async throws -> TicketMessage {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/tickets/\(ticketId)/messages")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "content": content,
            "senderType": "user"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }

        struct Resp: Decodable { let message: TicketMessage }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        guard let decoded = try? decoder.decode(Resp.self, from: data) else {
            let fallbackDecoder = JSONDecoder()
            fallbackDecoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let fallbackDecoded = try? fallbackDecoder.decode(Resp.self, from: data) else {
                throw APIError.decodingFailed
            }
            return fallbackDecoded.message
        }
        return decoded.message
    }

    func markTicketMessagesRead(ticketId: String, reader: String, supportUserId: String? = nil, token: String) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let baseUrl = base.appendingPathComponent("/api/tickets/\(ticketId)/messages/read")
        var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "reader", value: reader)]
        if let supportUserId {
            queryItems.append(URLQueryItem(name: "supportUserId", value: supportUserId))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data, allowEmptyBody: true)
    }

    // MARK: - Chat History

    func saveChatHistory(userId: String, chatId: String, messages: [ChatMessage], token: String) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        let url = base.appendingPathComponent("/api/chat/history")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let body: [String: Any] = [
            "userId": userId,
            "chatId": chatId,
            "messages": messages.map { [
                "role": $0.role,
                "content": $0.content,
                "timestamp": formatter.string(from: $0.timestamp)
            ]}
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }
    }

    func fetchChatHistory(userId: String, token: String, chatId: String? = nil) async throws -> [ChatMessage] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/chat/history"), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "userId", value: userId)]
        if let chatId = chatId {
            queryItems.append(URLQueryItem(name: "chatId", value: chatId))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }

        struct Resp: Decodable {
            let messages: [ChatMessageResponse]
        }

        struct ChatMessageResponse: Decodable {
            let role: String
            let content: String
            let timestamp: String
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        guard let decoded = try? decoder.decode(Resp.self, from: data) else {
            let fallbackDecoder = JSONDecoder()
            fallbackDecoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let fallbackDecoded = try? fallbackDecoder.decode(Resp.self, from: data) else {
                return []
            }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        return fallbackDecoded.messages.map { msg in
            let timestamp: Date
            if let parsed = formatter.date(from: msg.timestamp) {
                timestamp = parsed
            } else if let parsed = fallbackFormatter.date(from: msg.timestamp) {
                timestamp = parsed
            } else {
                timestamp = Date()
            }
            return ChatMessage(
                role: msg.role,
                content: msg.content,
                timestamp: timestamp
            )
        }
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    let fallbackFormatter = ISO8601DateFormatter()
    fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    return decoded.messages.map { msg in
        let timestamp: Date
        if let parsed = formatter.date(from: msg.timestamp) {
            timestamp = parsed
        } else if let parsed = fallbackFormatter.date(from: msg.timestamp) {
            timestamp = parsed
        } else {
            timestamp = Date()
        }
        return ChatMessage(
            role: msg.role,
            content: msg.content,
            timestamp: timestamp
        )
    }
    }

    func deleteChatHistory(userId: String, token: String, chatId: String? = nil) async throws {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/chat/history"), resolvingAgainstBaseURL: false)
        if let chatId = chatId {
            components?.queryItems = [URLQueryItem(name: "chatId", value: chatId)]
        }
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.requestFailed("Status \((response as? HTTPURLResponse)?.statusCode ?? 0): \(message)")
        }
    }
}
