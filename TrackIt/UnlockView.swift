import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var session: SessionManager
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.backgroundTop, Palette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                RadialGradient(
                    gradient: Gradient(colors: [Palette.accent.opacity(0.25), Palette.accentAlt.opacity(0.2), .clear]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 420
                )
                .blur(radius: 80)
            )

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                Text("Unlock TrackIt")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Face ID or device passcode is required")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button {
                    Task { await unlock() }
                } label: {
                    HStack {
                        if loading { ProgressView().tint(.white) }
                        Text("Unlock")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [Palette.accent, Palette.accentAlt], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                    .shadow(color: Palette.accent.opacity(0.35), radius: 18, x: 0, y: 10)
                }
                .disabled(loading)
            }
            .padding()
        }
        .task {
            if !session.isUnlocked && session.shouldPromptUnlock() {
                await unlock()
            }
        }
    }

    private func unlock() async {
        guard !session.unlocking else { return }
        await MainActor.run {
            loading = true
            error = nil
        }
        let success = await session.unlockWithBiometrics()
        await MainActor.run {
            if !success && !session.isUnlocked {
                error = "Authentication failed. Try again."
            }
            loading = false
        }
    }
}
