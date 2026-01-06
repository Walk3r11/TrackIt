import SwiftUI

@main
struct TrackItApp: App {
    @StateObject private var session = SessionManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var blurActive = false
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        checkAndCleanOnFirstLaunch()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    ContentView()
                        .environmentObject(session)
                } else {
                    AuthView()
                        .environmentObject(session)
                }
            }
            .onAppear {
                Task { await session.refreshSession() }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    blurActive = false
                case .inactive, .background:
                    blurActive = true
                default:
                    break
                }
            }
            .blur(radius: blurActive ? 34 : 0)
            .overlay(
                blurActive ?
                    LinearGradient(
                        colors: [Color.black.opacity(0.72), Color.black.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    ).ignoresSafeArea()
                    : nil
            )
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

// MARK: - First Launch
private func checkAndCleanOnFirstLaunch() {
    let hasLaunchedBeforeKey = "TrackIt.hasLaunchedBefore"
    
    if !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey) {
        print("🔄 First launch detected - clearing all app data for fresh install")
        
        let secureStoreKeys = [
            "userProfile",
            "authToken",
            "sessionCreatedAt",
            "cards",
            "transactions",
            "categories"
        ]
        SecureStore.delete(keys: secureStoreKeys)
        print("✅ Cleared \(secureStoreKeys.count) SecureStore (Keychain) keys")
        
        let userDefaultsKeys = [
            "sequenceCounter",
            "showSavingsCard",
            "savingsGoalAmount",
            "savingsSavedAmount",
            "savingsGoalPeriod",
            "requireCardUnlock",
            "categoryColorMap.v1"
        ]
        userDefaultsKeys.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        let prefixesToRemove = [
            "cardLimitAlertSignature.",
            "cardLimitAlertLastTx."
        ]
        for key in allKeys {
            for prefix in prefixesToRemove {
                if key.hasPrefix(prefix) {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        
        print("✅ Cleared UserDefaults keys")
        
        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        print("✅ First launch cleanup complete - app is ready for fresh start")
    }
}
