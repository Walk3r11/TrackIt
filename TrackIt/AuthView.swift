import SwiftUI
#if canImport(UIKit)
import UIKit
typealias KeyboardType = UIKeyboardType
typealias AutocapType = UITextAutocapitalizationType
#else
typealias KeyboardType = Int
typealias AutocapType = Int

extension KeyboardType {
    static var `default`: KeyboardType { 0 }
    static var emailAddress: KeyboardType { 1 }
}

extension AutocapType {
    static var words: AutocapType { 0 }
    static var none: AutocapType { 1 }
    static var sentences: AutocapType { 2 }
}
#endif

struct AuthView: View {
    @EnvironmentObject var session: SessionManager
    @State private var mode: AuthMode = .signup
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.backgroundTop, Palette.backgroundMid, Palette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                HeaderBadge(mode: mode)

                VStack(spacing: 16) {
                    Text("TrackIt Access")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Palette.primary)
                    Text(mode == .login ? "Secure login for admins and support" : "Create your admin seat")
                        .foregroundStyle(Palette.secondary)
                        .font(.callout)
                }

                ModeSegment(mode: $mode)

                VStack(spacing: 12) {
                    if mode == .signup {
                        FloatingField(title: "First name", text: $firstName)
                        FloatingField(title: "Last name", text: $lastName)
                    }
                    FloatingField(title: "Email", text: $email, keyboard: .emailAddress, autocap: .none)
                    SecureFloatingField(title: "Password", text: $password)
                }

                VStack(spacing: 10) {
                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if loading { ProgressView().tint(.white) }
                            Text(mode == .login ? "Login" : "Create account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Palette.accent, Palette.accentAlt],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(18)
                        .shadow(color: Palette.accent.opacity(0.35), radius: 22, x: 0, y: 14)
                    }
                    .disabled(loading || !canSubmit)

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
        }
    }

    private var canSubmit: Bool {
        if mode == .signup {
            return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func submit() {
        error = nil
        loading = true
        Task {
            do {
                var payload: [String: String] = [
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "password": password
                ]
                if mode == .signup {
                    payload["firstName"] = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    payload["lastName"] = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                let auth = try await APIClient.shared.authenticate(mode: mode, payload: payload)
                let resolvedSequence: String
                if let seq = auth.user.sequenceId, !seq.isEmpty {
                    resolvedSequence = seq
                } else {
                    resolvedSequence = SequenceGenerator.next()
                }
                let profile = UserProfile(
                    id: auth.user.id,
                    sequenceId: resolvedSequence,
                    firstName: auth.user.firstName,
                    lastName: auth.user.lastName,
                    email: auth.user.email,
                    balance: auth.user.balance,
                    monthlySpend: auth.user.monthlySpend,
                    lastActive: auth.user.lastActive
                )
                await MainActor.run {
                    session.setSession(user: profile, token: auth.token)
                }
            } catch {
                await MainActor.run {
                    self.error = "Request failed. Check credentials and try again."
                }
            }
            await MainActor.run {
                loading = false
            }
        }
    }
}

private struct FloatingField: View {
    let title: String
    @Binding var text: String
    var keyboard: KeyboardType = {
#if canImport(UIKit)
        .default
#else
        0
#endif
    }()
    var autocap: AutocapType = {
#if canImport(UIKit)
        .words
#else
        .sentences
#endif
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
            TextField(title, text: $text)
                .textContentType(.none)
#if canImport(UIKit)
                .keyboardType(keyboard)
                .autocapitalization(autocap)
#endif
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(CardBackground())
                .foregroundStyle(.white)
        }
    }
}

private struct SecureFloatingField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
            SecureField(title, text: $text)
                .textContentType(.password)
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(CardBackground())
                .foregroundStyle(.white)
        }
    }
}

private struct ModeSegment: View {
    @Binding var mode: AuthMode
    var body: some View {
        HStack(spacing: 8) {
            ForEach(AuthMode.allCases, id: \.self) { option in
                Button {
                    mode = option
                } label: {
                    Text(option == .signup ? "Sign Up" : "Login")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(mode == option ? Palette.mutedFill.opacity(0.8) : Palette.mutedFill.opacity(0.4))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Palette.stroke, lineWidth: 1)
                        )
                        .foregroundStyle(mode == option ? Palette.primary : Palette.secondary)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Palette.mutedFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }
}

private struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Palette.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Palette.stroke, lineWidth: 1)
            )
            .shadow(color: Palette.stroke.opacity(0.4), radius: 12, x: 0, y: 8)
    }
}

private struct HeaderBadge: View {
    let mode: AuthMode
    var body: some View {
        HStack(spacing: 10) {
            Label(mode == .login ? "Login" : "New user", systemImage: mode == .login ? "lock.fill" : "sparkles")
                .font(.footnote.bold())
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
