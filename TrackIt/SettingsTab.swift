import SwiftUI

struct SettingsTab: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var categories: [String]
    @Binding var requireCardUnlock: Bool
    @Binding var supportTickets: [SupportTicket]
    @Binding var showSupportSheet: Bool
    var onToggleCardLock: (Bool) -> Void
    
    @State private var showDeleteConfirmation = false
    @State private var showPasswordReset = false
    @State private var showHelpCenter = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showContactSupport = false
    @State private var showTickets = false
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("spendingLimitAlerts") private var spendingLimitAlerts = true
    @AppStorage("weeklyReports") private var weeklyReports = false

    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 20) {
                    accountSection
                    securitySection
                    preferencesSection
                    dataSection
                    categoriesSection
                    supportSection
                    aboutSection
                    actionsSection
                }
                .frame(maxWidth: LayoutMetrics.maxContentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.vertical, 20)
            }
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetSheet(isPresented: $showPasswordReset)
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterSheet(isPresented: $showHelpCenter)
            }
        .sheet(isPresented: $showTerms) {
            LegalSheet(title: "Terms of Service", content: termsOfServiceContent, isPresented: $showTerms)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalSheet(title: "Privacy Policy", content: privacyPolicyContent, isPresented: $showPrivacy)
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportSheet(isPresented: $showContactSupport)
            }
        .sheet(isPresented: $showTickets) {
            TicketsSheet(tickets: $supportTickets, showNewTicket: $showSupportSheet, isPresented: $showTickets)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if let userId = session.user?.id {
                        try? await APIClient.shared.deleteAccount(userId: userId)
                    }
                    await MainActor.run {
                        session.logout()
                    }
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }
    
    private var accountSection: some View {
        SettingsSection(title: "Account", icon: "person.circle.fill") {
            SettingsRow(
                icon: "person.fill",
                title: "Profile",
                subtitle: fullName,
                iconColor: Palette.accent
            )
            
            SettingsRow(
                icon: "envelope.fill",
                title: "Email",
                subtitle: session.user?.email ?? "Not available",
                iconColor: Palette.accentAlt
            )
            
            if let balance = session.user?.balance {
                SettingsRow(
                    icon: "dollarsign.circle.fill",
                    title: "Balance",
                    subtitle: balance.formatted(.currency(code: "EUR")),
                    iconColor: Palette.success
                )
            }
        }
    }
    
    private var securitySection: some View {
        SettingsSection(title: "Security & Privacy", icon: "lock.shield.fill") {
            ToggleRow(
                icon: "faceid",
                title: "Require Face ID for Cards",
                subtitle: "Keeps card details locked until you authenticate",
                isOn: $requireCardUnlock,
                iconColor: Palette.accent
            ) { newValue in
                onToggleCardLock(newValue)
            }
            
            Button {
                showPasswordReset = true
            } label: {
                SettingsRow(
                    icon: "key.fill",
                    title: "Change Password",
                    subtitle: "Update your account password",
                    iconColor: Palette.warning,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var preferencesSection: some View {
        SettingsSection(title: "Notifications", icon: "bell.fill") {
            ToggleRow(
                icon: "bell.fill",
                title: "Enable Notifications",
                subtitle: "Receive alerts and updates",
                isOn: $notificationsEnabled,
                iconColor: Palette.accentAlt
            ) { _ in }
            
            if notificationsEnabled {
                ToggleRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Spending Limit Warnings",
                    subtitle: "Alert when approaching card limits",
                    isOn: $spendingLimitAlerts,
                    iconColor: Palette.warning
                ) { _ in }
                
                ToggleRow(
                    icon: "chart.bar.fill",
                    title: "Weekly Reports",
                    subtitle: "Receive weekly spending summaries",
                    isOn: $weeklyReports,
                    iconColor: Palette.accentAlt
                ) { _ in }
            }
        }
    }
    
    private var dataSection: some View {
        SettingsSection(title: "Data & Sync", icon: "icloud.fill") {
            SettingsRow(
                icon: "arrow.down.circle.fill",
                title: "Export Data",
                subtitle: "Download your transaction history",
                iconColor: Palette.accent,
                showChevron: true
            )
            .onTapGesture {
                exportData()
            }
            
            SettingsRow(
                icon: "arrow.up.circle.fill",
                title: "Import Data",
                subtitle: "Upload transactions from file",
                iconColor: Palette.accentAlt,
                showChevron: true
            )
            .onTapGesture {
                importData()
            }
            
            SettingsRow(
                icon: "arrow.clockwise.circle.fill",
                title: "Sync Now",
                subtitle: "Manually refresh all data",
                iconColor: Palette.success,
                showChevron: true
            )
            .onTapGesture {
                syncNow()
            }
        }
    }

    private var categoriesSection: some View {
        SettingsSection(title: "Categories", icon: "tag.fill") {
            if categories.isEmpty {
                VStack(spacing: 8) {
                    Text("No categories yet")
                        .font(.subheadline)
                        .foregroundColor(Palette.secondary)
                    Text("Add categories from transaction details")
                        .font(.caption)
                        .foregroundColor(Palette.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        CategoryTag(text: category)
                    }
                }
                .padding(.top, 4)
                
                    Button {
                        Task {
                            guard let userId = session.user?.id else {
                                await MainActor.run { categories.removeAll() }
                                return
                            }
                            do {
                                let remote = try await APIClient.shared.clearCategories(userId: userId)
                                await MainActor.run { categories = remote }
                            } catch {
                                await MainActor.run { categories.removeAll() }
                            }
                        }
                    } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Categories")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.cardAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.danger.opacity(0.3), lineWidth: 1))
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var supportSection: some View {
        SettingsSection(title: "Help & Support", icon: "questionmark.circle.fill") {
            Button {
                showHelpCenter = true
            } label: {
                SettingsRow(
                    icon: "book.fill",
                    title: "Help Center",
                    subtitle: "FAQs and guides",
                    iconColor: Palette.accent,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
            
            Button {
                showTickets = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "lifepreserver.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Palette.accentAlt)
                        .frame(width: 32, height: 32)
                        .background(Palette.accentAlt.opacity(0.15), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Support Tickets")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Palette.primary)
                        Text("\(supportTickets.count) \(supportTickets.count == 1 ? "ticket" : "tickets")")
                            .font(.caption)
                            .foregroundColor(Palette.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Palette.secondary.opacity(0.5))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button {
                showContactSupport = true
            } label: {
                SettingsRow(
                    icon: "message.fill",
                    title: "Contact Support",
                    subtitle: "Get help from our team",
                    iconColor: Palette.accentAlt,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
            
            SettingsRow(
                icon: "star.fill",
                title: "Rate App",
                subtitle: "Share your feedback",
                iconColor: Palette.warning,
                showChevron: true
            )
            .onTapGesture {
                rateApp()
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle.fill") {
            SettingsRow(
                icon: "app.badge.fill",
                title: "Version",
                subtitle: appVersion,
                iconColor: Palette.secondary
            )
            
            Button {
                showTerms = true
            } label: {
                SettingsRow(
                    icon: "doc.text.fill",
                    title: "Terms of Service",
                    subtitle: "Read our terms and conditions",
                    iconColor: Palette.secondary,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
            
            Button {
                showPrivacy = true
            } label: {
                SettingsRow(
                    icon: "hand.raised.fill",
                    title: "Privacy Policy",
                    subtitle: "How we protect your data",
                    iconColor: Palette.secondary,
                    showChevron: true
                )
                    }
                    .buttonStyle(.plain)
                }
            }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                session.logout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Log Out")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Palette.accentAlt, Palette.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Account")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.red.opacity(0.8), Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
        }
    }
    
    private func exportData() {
        print("Export data functionality")
    }
    
    private func importData() {
        print("Import data functionality")
    }
    
    private func syncNow() {
        print("Sync now functionality")
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id\(Bundle.main.bundleIdentifier ?? "")") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    private var fullName: String {
        guard let user = session.user else { return "Not available" }
        return "\(user.firstName) \(user.lastName)"
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown"
    }
    
    private var termsOfServiceContent: String {
        """
        TERMS OF SERVICE
        
        Last Updated: January 2025
        
        1. ACCEPTANCE OF TERMS
        By accessing and using TrackIt, you accept and agree to be bound by these Terms of Service.
        
        2. DESCRIPTION OF SERVICE
        TrackIt is a personal finance management application that helps users track transactions, manage cards, and monitor spending.
        
        3. USER ACCOUNTS
        You are responsible for maintaining the confidentiality of your account credentials. You agree to notify us immediately of any unauthorized use.
        
        4. USER CONDUCT
        You agree not to use the service for any unlawful purpose or in any way that could damage, disable, or impair the service.
        
        5. DATA AND PRIVACY
        Your use of TrackIt is also governed by our Privacy Policy. We take data security seriously and implement industry-standard measures.
        
        6. LIMITATION OF LIABILITY
        TrackIt is provided "as is" without warranties of any kind. We are not liable for any indirect, incidental, or consequential damages.
        
        7. MODIFICATIONS
        We reserve the right to modify these terms at any time. Continued use after changes constitutes acceptance.
        
        8. TERMINATION
        We may terminate or suspend your account at any time for violations of these terms.
        
        9. CONTACT
        For questions about these terms, contact support through the app.
        """
    }
    
    private var privacyPolicyContent: String {
        """
        PRIVACY POLICY
        
        Last Updated: January 2025
        
        1. INFORMATION WE COLLECT
        We collect information you provide directly, including name, email, transaction data, and card information.
        
        2. HOW WE USE YOUR INFORMATION
        We use your information to:
        - Provide and improve our services
        - Process transactions and manage your account
        - Send important notifications
        - Detect and prevent fraud
        
        3. DATA STORAGE AND SECURITY
        Your data is encrypted and stored securely. We use industry-standard security measures to protect your information.
        
        4. DATA SHARING
        We do not sell your personal information. We may share data only with service providers necessary to operate the app.
        
        5. YOUR RIGHTS
        You have the right to:
        - Access your personal data
        - Request data deletion
        - Export your data
        - Opt-out of certain communications
        
        6. COOKIES AND TRACKING
        We use minimal tracking for app functionality and analytics. You can control this through your device settings.
        
        7. CHILDREN'S PRIVACY
        Our service is not intended for users under 13 years of age.
        
        8. CHANGES TO THIS POLICY
        We may update this policy. We will notify you of significant changes.
        
        9. CONTACT US
        For privacy concerns, contact us through the app's support feature.
        """
    }
}

private struct PasswordResetSheet: View {
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @EnvironmentObject private var session: SessionManager
    
    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)
            
            VStack(spacing: 24) {
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Palette.accent)
                    
                    Spacer()
                    
                    Text("Reset Password")
                        .font(.title2.bold())
                        .foregroundColor(Palette.primary)
                    
                    Spacer()
                    
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(successMessage != nil ? Palette.accent : .clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    if successMessage != nil {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Palette.success)
                            Text(successMessage ?? "")
                                .font(.subheadline)
                                .foregroundColor(Palette.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enter your email address and we'll send you a password reset link.")
                                .font(.subheadline)
                                .foregroundColor(Palette.secondary)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundColor(Palette.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Palette.card, Palette.cardAlt],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Palette.stroke, lineWidth: 1)
                                )
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Palette.danger)
                            }
                            
                            Button {
                                requestReset()
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Send Reset Link")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Palette.accentAlt, Palette.accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                            }
                            .disabled(isLoading || email.isEmpty)
                        }
                        .padding(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Palette.card, Palette.cardAlt],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .onAppear {
            email = session.user?.email ?? ""
        }
    }
    
    private func requestReset() {
        guard !email.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await APIClient.shared.requestPasswordReset(email: email)
                await MainActor.run {
                    isLoading = false
                    successMessage = "A password reset link has been sent to \(email). Please check your email."
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to send reset link. Please try again."
                }
            }
        }
    }
}

private struct HelpCenterSheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        FAQSection(title: "Getting Started", items: [
                            ("How do I add a transaction?", "Swipe down on the home screen or tap the + button to add a new transaction."),
                            ("How do I create a card?", "Go to the Cards tab and tap the + button to add a new card with a spending limit."),
                            ("How do I set up categories?", "Categories are automatically created when you add transactions. You can manage them in Settings.")
                        ])
                        
                        FAQSection(title: "Transactions", items: [
                            ("How do I edit a transaction?", "Tap on any transaction in the Recent Transactions section to edit or delete it."),
                            ("Can I export my transactions?", "Yes, go to Settings > Data & Sync > Export Data to download your transaction history."),
                            ("How are transactions categorized?", "Transactions are categorized based on the merchant name. You can manually adjust categories.")
                        ])
                        
                        FAQSection(title: "Cards & Limits", items: [
                            ("What are spending limits?", "Spending limits help you control your spending. You can set daily, weekly, or monthly limits."),
                            ("How do I unlock a card?", "If Face ID is enabled, use Face ID to unlock card details. Otherwise, cards are always visible."),
                            ("What happens when I exceed a limit?", "You'll receive a notification and the card will be highlighted in red.")
                        ])
                        
                        FAQSection(title: "AI Assistant", items: [
                            ("What can the AI help with?", "The AI can answer questions about your spending, provide financial advice, and analyze your transactions."),
                            ("Is my data secure?", "Yes, all AI interactions are encrypted and your data is never shared with third parties."),
                            ("How do I start a new chat?", "Tap the + button in the AI tab to start a fresh conversation.")
                        ])
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Palette.accent)
                }
            }
        }
    }
}

private struct FAQSection: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(Palette.primary)
            
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.0)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.accent)
                    Text(item.1)
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Palette.card, Palette.cardAlt],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
            }
        }
    }
}

private struct LegalSheet: View {
    let title: String
    let content: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                
                ScrollView {
                    Text(content)
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Palette.card, Palette.cardAlt],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Palette.stroke, lineWidth: 1)
                        )
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        .padding(.vertical, 20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Palette.accent)
                }
            }
        }
    }
}

private struct ContactSupportSheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Need help? We're here for you!")
                            .font(.headline)
                            .foregroundColor(Palette.primary)
                            .padding(.top, 20)
                        
                        Text("For support, please use the Tickets tab in the app to submit a support ticket. Our team typically responds within 24 hours.")
                            .font(.subheadline)
                            .foregroundColor(Palette.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ContactInfoRow(icon: "envelope.fill", title: "Email", value: "support@trackitco.com")
                            ContactInfoRow(icon: "clock.fill", title: "Response Time", value: "Within 24 hours")
                            ContactInfoRow(icon: "globe.fill", title: "Website", value: "trackitco.com")
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Palette.card, Palette.cardAlt],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Palette.stroke, lineWidth: 1)
                        )
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Palette.accent)
                }
            }
        }
    }
}

private struct ContactInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Palette.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
            }
            
            Spacer()
        }
    }
}

private struct TicketsSheet: View {
    @Binding var tickets: [SupportTicket]
    @Binding var showNewTicket: Bool
    @Binding var isPresented: Bool
    @State private var selectedTicket: SupportTicket?
    @EnvironmentObject private var session: SessionManager
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if tickets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "lifepreserver.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Palette.secondary)
                                Text("No tickets yet")
                                    .font(.headline)
                                    .foregroundColor(Palette.primary)
                                Text("Create a ticket to reach support")
                                    .font(.subheadline)
                                    .foregroundColor(Palette.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            } else {
                            VStack(spacing: 10) {
                                ForEach(tickets) { ticket in
                                    Button {
                                        selectedTicket = ticket
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(ticket.subject)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundColor(Palette.primary)
                                                Text(ticket.detail)
                                                    .font(.caption)
                                                    .foregroundColor(Palette.secondary)
                                                    .lineLimit(2)
                                            }
                                            Spacer()
                                            Text(ticket.status.rawValue.capitalized)
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(ticket.status == .open ? Palette.accent : Palette.accentAlt)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                            .background(Palette.mutedFill, in: Capsule())
                                        }
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                colors: [Palette.card, Palette.cardAlt],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Palette.stroke, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                    }
                }
                            .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        }
                    }
                    .padding(.vertical, 16)
            }
        }
            .navigationTitle("Support Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(Palette.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewTicket = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Palette.accent)
                    }
                }
            }
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketChatView(ticket: ticket)
                .environmentObject(session)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Palette.accent)
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(Palette.primary)
            }
            
            VStack(spacing: 0) {
                content
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Palette.card, Palette.cardAlt],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    var showChevron: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Palette.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let iconColor: Color
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Palette.accent)
                .labelsHidden()
                .onChange(of: isOn) { _, newValue in
                    onToggle(newValue)
                }
        }
        .padding(.vertical, 12)
    }
}

private struct CategoryTag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(Palette.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Palette.mutedFill, Palette.mutedFill.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
    }
}
