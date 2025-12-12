import Foundation
import Combine
import SwiftUI
import LocalAuthentication

struct UserProfile: Codable, Equatable {
    let id: String
    let sequenceId: String?
    let firstName: String
    let lastName: String
    let email: String
    let balance: Double?
    let monthlySpend: Double?
    let lastActive: String?
}

enum SequenceGenerator {
    static func next() -> String {
        let current = UserDefaults.standard.integer(forKey: "sequenceCounter")
        let next = current + 1
        UserDefaults.standard.set(next, forKey: "sequenceCounter")
        return String(format: "T-%06d", next)
    }
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var user: UserProfile?
    @Published var token: String?
    @Published var verifying = false
    @Published var restoredFromStorage = false
    @Published var isUnlocked = false
    @Published var unlocking = false
    private var lastUnlockPrompt: Date?

    var isAuthenticated: Bool { user != nil && token != nil }

    init() {
        user = SecureStore.load(UserProfile.self, key: "userProfile")
        token = SecureStore.load(String.self, key: "authToken")
        restoredFromStorage = user != nil && token != nil
        isUnlocked = false
    }

    @MainActor
    func refreshSession() async {
        guard let current = user else { return }
        verifying = true
        defer { verifying = false }
        do {
            if let latest = try await APIClient.shared.fetchUser(byEmail: current.email) {
                user = latest
                SecureStore.save(latest, key: "userProfile")
            }
        } catch {
            // keep existing session if lookup failed for network reasons
        }
    }

    func setSession(user: UserProfile, token: String) {
        self.user = user
        self.token = token
        SecureStore.save(user, key: "userProfile")
        SecureStore.save(token, key: "authToken")
        restoredFromStorage = false
        isUnlocked = false
        lastUnlockPrompt = nil
    }

    func logout() {
        user = nil
        token = nil
        SecureStore.delete(keys: ["userProfile", "authToken", "cards", "transactions"])
        UserDefaults.standard.removeObject(forKey: "sequenceCounter")
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
