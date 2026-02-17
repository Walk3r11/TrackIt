import SwiftUI
import UIKit
import UserNotifications

@main
struct TrackItApp: App {
    @StateObject private var session = SessionManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var blurActive = false
    @AppStorage("didRequestLocalNotifications") private var didRequestLocalNotifications = false

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        checkAndCleanOnFirstLaunch()
        configureTabBarAppearance()
        requestLocalNotificationPermissionIfNeeded()
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
            .preferredColorScheme(.light)
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
                blurActive
                    ? Color.black.opacity(0.7).ignoresSafeArea()
                    : nil
            )
        }
    }
}

private func requestLocalNotificationPermissionIfNeeded() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: "didRequestLocalNotifications") { return }
    defaults.set(true, forKey: "didRequestLocalNotifications")
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
}

private func configureTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(Palette.card)
    appearance.shadowColor = UIColor(Palette.strokeStrong)
    UITabBar.appearance().standardAppearance = appearance
    if #available(iOS 15.0, *) {
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    UITabBar.appearance().tintColor = UIColor(Palette.accent)
    UITabBar.appearance().unselectedItemTintColor = UIColor(Palette.tertiary)
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UserDefaults.standard.removeObject(forKey: "currentChatId")
        SecureStore.delete(key: "currentChat")
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
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
