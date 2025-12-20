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
    static var numberPad: KeyboardType { 2 }
}

extension AutocapType {
    static var words: AutocapType { 0 }
    static var none: AutocapType { 1 }
    static var sentences: AutocapType { 2 }
}
#endif

private enum AuthStage {
    case credentials
    case verifyCode
    case resetRequest
}

struct AuthView: View {
    @EnvironmentObject var session: SessionManager
    @State private var mode: AuthMode = .signup
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var stage: AuthStage = .credentials
    @State private var verificationCode = ""
    @State private var status: String?
    @State private var loading = false
    @State private var error: String?
    @State private var didAppear = false

    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HeaderBadge(mode: mode)
                        .padding(.top, 34)

                    VStack(spacing: 8) {
                        Text("TrackIt Access")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.primary)
                        Text(mode == .login ? "Secure login for admins and support" : "Create your admin seat")
                            .foregroundStyle(Palette.secondary)
                            .font(.callout)
                    }

                VStack(spacing: 14) {
                    if stage == .credentials {
                        ModeSegment(mode: $mode)
                    }

                    VStack(spacing: 12) {
                        switch stage {
                        case .credentials:
                            if mode == .signup {
                                FloatingField(title: "First name", text: $firstName)
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)
                                        )
                                    )
                                FloatingField(title: "Last name", text: $lastName)
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)
                                        )
                                    )
                            }
                            FloatingField(title: "Email", text: $email, keyboard: .emailAddress, autocap: .none)
                            SecureFloatingField(title: "Password", text: $password, disableAutofill: mode == .login)
                        case .verifyCode:
                            Text("Enter the 6-digit code sent to \(email).")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            FloatingField(title: "Verification code", text: $verificationCode, keyboard: .numberPad, autocap: .none)
                        case .resetRequest:
                            Text("We will email you a password reset link.")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            FloatingField(title: "Email", text: $email, keyboard: .emailAddress, autocap: .none)
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stage)

                    VStack(spacing: 10) {
                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if loading { ProgressView().tint(.white) }
                                Text(primaryActionTitle)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Palette.accentAlt, Palette.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .foregroundStyle(.white)
                            .shadow(color: Palette.accent.opacity(0.35), radius: 22, x: 0, y: 14)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(loading || !canSubmit)

                        if let status {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(Palette.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let error {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Palette.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if stage == .verifyCode {
                            Button("Resend code") {
                                resendVerification()
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                        }

                        if stage == .credentials && mode == .login {
                            Button("Forgot password?") {
                                stage = .resetRequest
                                status = nil
                                error = nil
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                        }

                        if stage != .credentials {
                            Button("Back to login") {
                                stage = .credentials
                                status = nil
                                error = nil
                                mode = .login
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: error)
                }
                .padding(16)
                .glassCard(
                    cornerRadius: 22,
                    tint: mode == .login ? [Palette.accentAlt, Palette.accent] : [Palette.accent, Palette.accentAlt],
                    shadowColor: Palette.accent
                )

                Spacer(minLength: 28)
                }
                .frame(maxWidth: LayoutMetrics.maxContentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.bottom, 24)
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 12)
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: didAppear)
        }
        .onAppear {
            didAppear = true
        }
        .onChange(of: mode) { _, _ in
            stage = .credentials
            status = nil
            error = nil
        }
    }

    private var canSubmit: Bool {
        switch stage {
        case .credentials:
            if mode == .signup {
                return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty
            } else {
                return !email.isEmpty && !password.isEmpty
            }
        case .verifyCode:
            return !email.isEmpty && !verificationCode.isEmpty
        case .resetRequest:
            return !email.isEmpty
        }
    }

    private var primaryActionTitle: String {
        switch stage {
        case .credentials:
            return mode == .login ? "Login" : "Create account"
        case .verifyCode:
            return "Verify code"
        case .resetRequest:
            return "Send reset link"
        }
    }

    private func submit() {
        error = nil
        status = nil
        loading = true
        Task {
            switch stage {
            case .credentials:
                await submitCredentials()
            case .verifyCode:
                await submitVerification()
            case .resetRequest:
                await submitResetRequest()
            }
        }
    }

    private func submitCredentials() async {
        defer {
            Task {
                await MainActor.run {
                    loading = false
                    if mode == .login {
                        password = ""
                    }
                }
            }
        }
        do {
            if mode == .signup {
                if let passwordError = getPasswordValidationError(password) {
                    await MainActor.run {
                        self.error = passwordError
                    }
                    return
                }
            }
            var payload: [String: String] = [
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": password
            ]
            if mode == .signup {
                payload["firstName"] = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                payload["lastName"] = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let auth = try await APIClient.shared.authenticate(mode: mode, payload: payload)
            if mode == .signup {
                await MainActor.run {
                    stage = .verifyCode
                    status = "Check your email for the verification code."
                    verificationCode = ""
                }
                return
            }

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
            if let apiError = error as? APIError, case let .requestFailed(message) = apiError,
               message.localizedCaseInsensitiveContains("Email not verified") {
                await MainActor.run {
                    stage = .verifyCode
                    status = "Verify your email to finish login."
                    verificationCode = ""
                }
                resendVerification()
            } else {
                await MainActor.run {
                    if mode == .login {
                        self.error = "Incorrect password"
                    } else {
                        self.error = "Request failed. Please try again."
                    }
                }
            }
        }
    }

    private func submitVerification() async {
        defer {
            Task { await MainActor.run { loading = false } }
        }
        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            try await APIClient.shared.confirmVerification(email: cleanEmail, code: verificationCode)

            let auth = try await APIClient.shared.authenticate(mode: .login, payload: [
                "email": cleanEmail,
                "password": password
            ])
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
                self.error = "Verification failed. Check the code and try again."
            }
        }
    }

    private func submitResetRequest() async {
        defer {
            Task { await MainActor.run { loading = false } }
        }
        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            try await APIClient.shared.requestPasswordReset(email: cleanEmail)
            await MainActor.run {
                status = "Reset email sent. Check your inbox."
                stage = .credentials
                mode = .login
            }
        } catch {
            await MainActor.run {
                self.error = "Could not send reset email. Try again."
            }
        }
    }

    private func resendVerification() {
        Task {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            do {
                try await APIClient.shared.requestVerification(email: cleanEmail)
                await MainActor.run {
                    status = "Verification code sent."
                }
            } catch {
                await MainActor.run {
                    self.error = "Could not resend code."
                }
            }
        }
    }

    private func isValidPassword(_ value: String) -> Bool {
        let upper = value.range(of: "[A-Z]", options: .regularExpression) != nil
        let lower = value.range(of: "[a-z]", options: .regularExpression) != nil
        let number = value.range(of: "[0-9]", options: .regularExpression) != nil
        let special = value.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        return value.count >= 8 && upper && lower && number && special
    }
    
    private func getPasswordValidationError(_ value: String) -> String? {
        var missing: [String] = []
        
        if value.count < 8 {
            missing.append("at least 8 characters")
        }
        
        if value.range(of: "[A-Z]", options: .regularExpression) == nil {
            missing.append("an uppercase letter")
        }
        
        if value.range(of: "[a-z]", options: .regularExpression) == nil {
            missing.append("a lowercase letter")
        }
        
        if value.range(of: "[0-9]", options: .regularExpression) == nil {
            missing.append("a number")
        }
        
        if value.range(of: "[^A-Za-z0-9]", options: .regularExpression) == nil {
            missing.append("a special character")
        }
        
        if missing.isEmpty {
            return nil
        }
        
        if missing.count == 1 {
            return "Password must contain \(missing[0])."
        } else if missing.count == 2 {
            return "Password must contain \(missing[0]) and \(missing[1])."
        } else {
            let last = missing.removeLast()
            let others = missing.joined(separator: ", ")
            return "Password must contain \(others), and \(last)."
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
    var disableAutofill = false
    @State private var isSecure = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 10) {
                if isSecure {
                    SecureField(title, text: $text)
                        .textContentType(disableAutofill ? .oneTimeCode : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } else {
                    TextField(title, text: $text)
                        .textContentType(disableAutofill ? .oneTimeCode : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSecure ? "Show password" : "Hide password")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(CardBackground())
            .foregroundStyle(.white)
        }
    }
}

private struct ModeSegment: View {
    @Binding var mode: AuthMode
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AuthMode.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        mode = option
                    }
                } label: {
                    ZStack {
                        Capsule()
                            .fill(Palette.mutedFill.opacity(mode == option ? 0.18 : 0.28))

                        if mode == option {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Palette.accentAlt.opacity(0.75), Palette.accent.opacity(0.65)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "authModePill", in: selectionNamespace)
                                .shadow(color: Palette.accent.opacity(0.28), radius: 12, x: 0, y: 8)
                        }

                        Text(option == .signup ? "Sign Up" : "Login")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(mode == option ? Color.white : Palette.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.92))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.cardAlt.opacity(0.98))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), .clear, Color.black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .allowsHitTesting(false)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Palette.cardAlt.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1)
            )
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
