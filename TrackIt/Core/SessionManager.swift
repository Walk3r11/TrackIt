import Foundation
import Combine
import SwiftUI

struct UserProfile: Codable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let balance: Double?
    let monthlySpend: Double?
    let lastActive: String?
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var user: UserProfile?
    @Published var token: String?
    @Published var sessionValidated = false
    private var sessionCreatedAt: Date?
    private let sessionDuration: TimeInterval = 60 * 60 * 24 * 60

    var isAuthenticated: Bool { user != nil && token != nil }

    init() {
        user = nil
        token = nil
        sessionValidated = false
        restoreSessionFromStorage()
    }

    @MainActor
    func refreshSession() async {
        if let createdAt = sessionCreatedAt {
            let now = Date()
            if now.timeIntervalSince(createdAt) > sessionDuration {
                logout()
                return
            }
        }

        guard let token = token else { return }

        do {
            _ = try await APIClient.shared.validateSession(token: token)
            sessionValidated = true
        } catch {
            if let apiError = error as? APIError,
               case .requestFailed(let message) = apiError,
               (message.contains("401") || message.contains("Unauthorized") || message.contains("invalid session")) {
                logout()
            } else {
                sessionValidated = true
            }
        }
    }

    private func restoreSessionFromStorage() {
        if let storedUser: UserProfile = SecureStore.load(UserProfile.self, key: "userProfile"),
           let storedToken: String = SecureStore.load(String.self, key: "authToken"),
           let storedTimestamp: TimeInterval = SecureStore.load(TimeInterval.self, key: "sessionCreatedAt") {
            let storedDate = Date(timeIntervalSince1970: storedTimestamp)
            let now = Date()
            if now.timeIntervalSince(storedDate) <= sessionDuration {
                self.user = storedUser
                self.token = storedToken
                self.sessionCreatedAt = storedDate
                self.sessionValidated = false
            } else {
                print("⚠️ Session expired (stored: \(storedDate), now: \(now))")
                SecureStore.delete(keys: ["userProfile", "authToken", "sessionCreatedAt"])
            }
        }
    }

    func setSession(user: UserProfile, token: String) {
        self.user = user
        self.token = token
        self.sessionCreatedAt = Date()
        sessionValidated = true

        SecureStore.save(user, key: "userProfile")
        SecureStore.save(token, key: "authToken")
        if let createdAt = sessionCreatedAt {
            SecureStore.save(createdAt.timeIntervalSince1970, key: "sessionCreatedAt")
        }
    }

    func logout() {
        user = nil
        token = nil
        sessionCreatedAt = nil
        sessionValidated = false
        SecureStore.delete(keys: ["userProfile", "authToken", "sessionCreatedAt", "cards", "transactions", "chatHistories", "currentChat"])
        UserDefaults.standard.removeObject(forKey: "currentChatId")
    }
}
