import SwiftUI

@main
struct TrackItApp: App {
    @StateObject private var session = SessionManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var blurActive = false

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
                    Task { await session.refreshSession() }
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
