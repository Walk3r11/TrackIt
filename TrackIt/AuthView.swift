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
    @State private var sendingVerification = false
    @State private var pendingAuth: AuthResponse?
    @State private var error: String?
    @State private var didAppear = false

    var body: some View {
        ZStack {
            MinimalBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        BrandMark()
                        Spacer()
                        CapsuleTag(text: mode == .login ? "Login" : "Sign up")
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(headerTitle)
                            .font(.custom("Avenir Next", size: 32))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.black)
                        Text(headerSubtitle)
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }

                    if stage == .credentials {
                        ModeSwitch(mode: $mode)
                            .padding(.top, 6)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        switch stage {
                        case .credentials:
                            if mode == .signup {
                                MinimalField(title: "First name", text: $firstName)
                                MinimalField(title: "Last name", text: $lastName)
                            }
                            MinimalField(title: "Email", text: $email, keyboard: .emailAddress, autocap: .none)
                            MinimalSecureField(title: "Password", text: $password, disableAutofill: mode == .login)
                        case .verifyCode:
                            Text("Enter the 6-digit code sent to \(email).")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color.black.opacity(0.6))
                            MinimalField(title: "Verification code", text: $verificationCode, keyboard: .numberPad, autocap: .none)
                        case .resetRequest:
                            Text("We will email you a password reset link.")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color.black.opacity(0.6))
                            MinimalField(title: "Email", text: $email, keyboard: .emailAddress, autocap: .none)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: stage)

                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if loading { ProgressView().tint(.white) }
                                Text(primaryActionTitle)
                                    .font(.custom("Avenir Next", size: 16))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.black)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(loading || sendingVerification || !canSubmit)

                        if let status {
                            Text(status)
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundStyle(Color.black.opacity(0.6))
                        }

                        if let error {
                            Text(error)
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundStyle(Color.red.opacity(0.85))
                        }

                        if stage == .verifyCode {
                            Button {
                                resendVerification()
                            } label: {
                                HStack(spacing: 8) {
                                    if sendingVerification {
                                        ProgressView().tint(.black)
                                    }
                                    Text(sendingVerification ? "Sending code..." : "Resend verification code")
                                }
                                .font(.custom("Avenir Next", size: 14))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .foregroundStyle(Color.black)
                            .buttonStyle(PressableButtonStyle())
                            .disabled(sendingVerification)
                        }

                        if stage == .credentials && mode == .login {
                            Button("Forgot password?") {
                                stage = .resetRequest
                                status = nil
                                error = nil
                            }
                            .font(.custom("Avenir Next", size: 14))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.black.opacity(0.65))
                        }

                        if stage != .credentials {
                            Button("Back to login") {
                                stage = .credentials
                                status = nil
                                error = nil
                                pendingAuth = nil
                                verificationCode = ""
                                mode = .login
                            }
                            .font(.custom("Avenir Next", size: 14))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.black.opacity(0.65))
                        }
                    }
                    .padding(.top, 4)

                    Text("By continuing you agree to our Terms and Privacy Policy.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color.black.opacity(0.5))
                        .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .padding(24)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 10)
                .animation(.easeOut(duration: 0.3), value: didAppear)
            }
        }
        .onAppear {
            didAppear = true
        }
        .onChange(of: mode) { _, _ in
            stage = .credentials
            status = nil
            error = nil
            pendingAuth = nil
            verificationCode = ""
        }
    }

    private var headerTitle: String {
        switch stage {
        case .credentials:
            return mode == .login ? "Welcome back" : "Create your space"
        case .verifyCode:
            return "Verify your email"
        case .resetRequest:
            return "Reset your password"
        }
    }

    private var headerSubtitle: String {
        switch stage {
        case .credentials:
            return mode == .login ? "Sign in to keep your money in focus." : "A quiet workspace for modern finance."
        case .verifyCode:
            return "One last step before you get in."
        case .resetRequest:
            return "We will send you a secure reset link."
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
        var shouldClearPassword = mode == .login
        defer {
            Task {
                await MainActor.run {
                    loading = false
                    if shouldClearPassword {
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
                var payload: [String: String] = [
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "password": password
                ]
                payload["firstName"] = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                payload["lastName"] = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

                _ = try await APIClient.shared.authenticate(mode: .signup, payload: payload)
                await MainActor.run {
                    stage = .verifyCode
                    status = "Check your email for the verification code."
                    verificationCode = ""
                }
                return
            }

            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            log("Login attempt for \(maskedEmail(cleanEmail))")
            let auth: AuthResponse
            do {
                auth = try await APIClient.shared.authenticate(mode: .login, payload: [
                    "email": cleanEmail,
                    "password": password
                ])
                log("Login credential check succeeded for \(maskedEmail(cleanEmail))")
            } catch {
                log("Login credential check failed for \(maskedEmail(cleanEmail)): \(error)")
                if let apiError = error as? APIError, case let .requestFailed(message) = apiError,
                   message.localizedCaseInsensitiveContains("Email not verified") {
                    shouldClearPassword = false
                    await MainActor.run {
                        stage = .verifyCode
                        status = "Verify your email to finish login."
                        verificationCode = ""
                    }
                    log("Email not verified for \(maskedEmail(cleanEmail)); requesting verification code")
                    resendVerification()
                } else {
                    await MainActor.run {
                        self.error = "Incorrect email or password."
                    }
                }
                return
            }

            do {
                try await APIClient.shared.requestVerification(email: cleanEmail.lowercased())
                log("Verification code requested for \(maskedEmail(cleanEmail))")
            } catch {
                log("Verification code request failed for \(maskedEmail(cleanEmail)): \(error)")
                await MainActor.run {
                    self.error = "Could not send verification code."
                }
                return
            }

            await MainActor.run {
                pendingAuth = auth
                stage = .verifyCode
                status = "Enter the code to finish login."
                verificationCode = ""
            }

            preloadUserData(userId: auth.user.id, token: auth.token)
        } catch {
            await MainActor.run {
                self.error = "Request failed. Please try again."
            }
        }
    }

    private func submitVerification() async {
        defer {
            Task { await MainActor.run { loading = false } }
        }
        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            log("Confirming verification code for \(maskedEmail(cleanEmail)) (length: \(verificationCode.count))")
            try await APIClient.shared.confirmVerification(email: cleanEmail, code: verificationCode)
            log("Verification code confirmed for \(maskedEmail(cleanEmail))")

            let auth: AuthResponse
            if let pending = pendingAuth {
                log("Using pending auth response for \(maskedEmail(cleanEmail))")
                auth = pending
            } else {
                log("No pending auth response; re-authenticating for \(maskedEmail(cleanEmail))")
                auth = try await APIClient.shared.authenticate(mode: .login, payload: [
                    "email": cleanEmail,
                    "password": password
                ])
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
                pendingAuth = nil
            }
            log("Login completed for \(maskedEmail(cleanEmail))")
        } catch {
            log("Verification flow failed: \(error)")
            await MainActor.run {
                if let apiError = error as? APIError, case let .requestFailed(message) = apiError {
                    let lowercased = message.lowercased()
                    if lowercased.contains("authentication failed") ||
                        lowercased.contains("invalid credentials") ||
                        lowercased.contains("incorrect") ||
                        lowercased.contains("unauthorized") {
                        self.error = "Incorrect password."
                        return
                    }
                }
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
            log("Password reset requested for \(maskedEmail(cleanEmail))")
            try await APIClient.shared.requestPasswordReset(email: cleanEmail)
            await MainActor.run {
                status = "Reset email sent. Check your inbox."
                stage = .credentials
                mode = .login
            }
            log("Password reset email sent for \(maskedEmail(cleanEmail))")
        } catch {
            log("Password reset request failed: \(error)")
            await MainActor.run {
                self.error = "Could not send reset email. Try again."
            }
        }
    }

    private func resendVerification() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else {
            error = "Enter your email to receive a verification code."
            return
        }
        log("Resend verification code requested for \(maskedEmail(cleanEmail))")
        sendingVerification = true
        error = nil
        status = nil
        Task {
            do {
                try await APIClient.shared.requestVerification(email: cleanEmail)
                await MainActor.run {
                    status = "Verification code sent."
                }
                log("Verification code sent for \(maskedEmail(cleanEmail))")
            } catch {
                log("Resend verification failed for \(maskedEmail(cleanEmail)): \(error)")
                await MainActor.run {
                    self.error = "Could not send verification code."
                }
            }
            await MainActor.run {
                sendingVerification = false
            }
        }
    }

    private func maskedEmail(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@") else { return trimmed }
        let name = trimmed[..<atIndex]
        let domain = trimmed[atIndex...]
        if name.count <= 2 {
            return "***" + domain
        }
        return name.prefix(2) + "..." + domain
    }

    private func log(_ message: String) {
        print("[Auth] \(message)")
    }

    private func preloadUserData(userId: String, token: String) {
        Task {
            log("Preloading user data for \(userId)")

            async let cardsTask = APIClient.shared.fetchCards(userId: userId, token: token)
            async let transactionsTask = APIClient.shared.fetchTransactions(userId: userId, token: token)
            async let categoriesTask = APIClient.shared.fetchCategories(userId: userId, token: token)
            async let savingsTask = APIClient.shared.fetchSavingsGoal(userId: userId, token: token)
            async let ticketsTask = APIClient.shared.fetchTickets(userId: userId, token: token)

            if let cards = try? await cardsTask {
                await MainActor.run {
                    SecureStore.save(cards, key: "cards")
                    log("Preloaded \(cards.count) cards")
                }
            }

            if let transactions = try? await transactionsTask {
                await MainActor.run {
                    SecureStore.save(transactions, key: "transactions")
                    log("Preloaded \(transactions.count) transactions")
                }
            }

            if let categories = try? await categoriesTask {
                await MainActor.run {
                    SecureStore.save(categories, key: "categories")
                    log("Preloaded \(categories.count) categories")
                }
            }

            if let savings = try? await savingsTask {
                await MainActor.run {
                    if savings.goalAmount > 0 {
                        UserDefaults.standard.set(true, forKey: "showSavingsCard")
                    }
                    UserDefaults.standard.set(savings.goalAmount, forKey: "savingsGoalAmount")
                    UserDefaults.standard.set(savings.goalPeriod.rawValue, forKey: "savingsGoalPeriod")
                    log("Preloaded savings goal")
                }
            }

            if let tickets = try? await ticketsTask {
                await MainActor.run {
                    SecureStore.save(tickets, key: "supportTickets")
                    log("Preloaded \(tickets.count) tickets")
                }
            }

            async let chatHistoryTask = APIClient.shared.fetchChatHistory(userId: userId, token: token)
            if let chatMessages = try? await chatHistoryTask, !chatMessages.isEmpty {
                let existing: [ChatMessage]? = SecureStore.load([ChatMessage].self, key: "currentChat")
                await MainActor.run {
                    if let existing = existing, existing.count >= chatMessages.count {
                        return
                    }
                    SecureStore.save(chatMessages, key: "currentChat")
                    log("Preloaded \(chatMessages.count) chat messages")
                }
            }

            log("Data preloading completed")
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

private struct BrandMark: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.black)
                Text("T")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            Text("TrackIt")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color.black)
        }
    }
}

private struct CapsuleTag: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.custom("Avenir Next", size: 11))
            .fontWeight(.semibold)
            .tracking(1.2)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.9))
            )
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            .foregroundStyle(Color.black.opacity(0.7))
    }
}

private struct MinimalField: View {
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
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color.black.opacity(0.6))
            TextField(title, text: $text)
                .textContentType(.none)
#if canImport(UIKit)
                .keyboardType(keyboard)
                .autocapitalization(autocap)
#endif
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(Color.black)
        }
    }
}

private struct MinimalSecureField: View {
    let title: String
    @Binding var text: String
    var disableAutofill = false
    @State private var isSecure = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color.black.opacity(0.6))
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
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSecure ? "Show password" : "Hide password")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .foregroundStyle(Color.black)
        }
    }
}

private struct ModeSwitch: View {
    @Binding var mode: AuthMode
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AuthMode.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        mode = option
                    }
                } label: {
                    ZStack {
                        if mode == option {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black)
                                .matchedGeometryEffect(id: "authModePill", in: selectionNamespace)
                        }
                        Text(option == .signup ? "Sign Up" : "Login")
                            .font(.custom("Avenir Next", size: 14))
                            .fontWeight(.semibold)
                            .foregroundStyle(mode == option ? Color.white : Color.black.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.92))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}
