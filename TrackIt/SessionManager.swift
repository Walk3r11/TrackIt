import Foundation
import Combine
import SwiftUI
import LocalAuthentication

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
    @Published var verifying = false
    @Published var restoredFromStorage = false
    @Published var isUnlocked = false
    @Published var unlocking = false
    private var lastUnlockPrompt: Date?
    private var sessionCreatedAt: Date?
    private let sessionDuration: TimeInterval = 60 * 60 * 24 * 60

    var isAuthenticated: Bool { user != nil && token != nil }

    init() {
        user = nil
        token = nil
        restoredFromStorage = false
        sessionValidated = false
        isUnlocked = false
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
                self.restoredFromStorage = true
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
        restoredFromStorage = false
        sessionValidated = true
        isUnlocked = false
        lastUnlockPrompt = nil

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
        restoredFromStorage = false
        isUnlocked = false
        lastUnlockPrompt = nil
    }

    func markLocked() {
        isUnlocked = false
        unlocking = false
    }

    func shouldPromptUnlock() -> Bool {
        if isUnlocked { return false }
        let now = Date()
        if let last = lastUnlockPrompt, now.timeIntervalSince(last) < 10 {
            return false
        }
        return true
    }

    func unlockWithBiometrics() async -> Bool {
        if unlocking { return false }
        if isUnlocked { return true }
        unlocking = true
        defer { unlocking = false }
        lastUnlockPrompt = Date()
        let context = LAContext()
        var error: NSError?
        let reason = "Authenticate to access TrackIt"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = true
            lastUnlockPrompt = Date()
            return true
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success { isUnlocked = true }
            lastUnlockPrompt = Date()
            return success
        } catch {
            lastUnlockPrompt = Date()
            return false
        }
    }
}
