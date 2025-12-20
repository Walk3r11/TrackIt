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
            let cardId: String?
            let amount: String
            let category: String
            let createdAt: String

            enum CodingKeys: String, CodingKey {
                case id
                case cardId
                case card_id
                case amount
                case category
                case createdAt
                case created_at
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                cardId = try container.decodeIfPresent(String.self, forKey: .cardId)
                    ?? container.decodeIfPresent(String.self, forKey: .card_id)
                if let amountString = try container.decodeIfPresent(String.self, forKey: .amount) {
                    amount = amountString
                } else if let amountNumber = try container.decodeIfPresent(Double.self, forKey: .amount) {
                    amount = String(amountNumber)
                } else {
                    amount = "0"
                }
                category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
                createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
                    ?? container.decodeIfPresent(String.self, forKey: .created_at)
                    ?? ""
            }
        }
        struct Resp: Decodable { let transactions: [TxRow] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(Resp.self, from: data) else { throw APIError.decodingFailed }
        let df = ISO8601DateFormatter()
        return decoded.transactions.map { row in
            let amountDouble: Double
            if let number = Double(row.amount) {
                amountDouble = number
            } else if let num = NumberFormatter().number(from: row.amount) {
                amountDouble = num.doubleValue
            } else {
                amountDouble = 0
            }
            return Transaction(
                id: UUID(uuidString: row.id) ?? UUID(),
                cardId: row.cardId.flatMap { UUID(uuidString: $0) },
                amount: amountDouble,
                category: row.category,
                date: df.date(from: row.createdAt) ?? .now,
                kind: amountDouble >= 0 ? .income : .expense
            )
        }
    }

    func fetchCategories(userId: String) async throws -> [String] {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/categories"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
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

    func fetchSavingsGoal(userId: String) async throws -> (goalAmount: Double, goalPeriod: SpendingLimitPeriod) {
        guard let base = baseURL else { throw APIError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("/api/savings"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
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
}
