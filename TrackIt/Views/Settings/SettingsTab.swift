import SwiftUI
import UIKit

struct SettingsTab: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var categories: [String]
    @Binding var requireCardUnlock: Bool
    @Binding var supportTickets: [SupportTicket]
    @Binding var showSupportSheet: Bool
    var transactions: [Transaction]
    var cards: [CardInfo]
    var onToggleCardLock: (Bool) -> Void
    var onSyncNow: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var showPasswordReset = false
    @State private var showHelpCenter = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showTickets = false
    @State private var exportItem: ExportFileItem?

    @AppStorage("pendingSupportTicketId") private var pendingSupportTicketId = ""

    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    accountSection
                    securitySection
                    dataSection
                    categoriesSection
                    supportSection
                    aboutSection
                    actionSection
                }
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        }
        .onAppear { handlePendingSupportTicket() }
        .onChange(of: pendingSupportTicketId) { _, _ in handlePendingSupportTicket() }
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
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $showTickets) {
            TicketsSheet(
                tickets: $supportTickets,
                showNewTicket: $showSupportSheet,
                isPresented: $showTickets,
                pendingTicketId: $pendingSupportTicketId
            )
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.appFont(size: 28, weight: .semibold))
                .foregroundStyle(Palette.primary)
            Text("Manage your account and preferences")
                .font(.appFont(size: 13))
                .foregroundStyle(Palette.secondary)
        }
    }

    private var accountSection: some View {
        SettingsBlock(title: "Account") {
            SettingsLine(label: "Profile", value: fullName)
            SettingsLine(label: "Email", value: session.user?.email ?? "Not available")
            if let balance = session.user?.balance {
                SettingsLine(label: "Balance", value: balance.formattedAsCurrency())
            }
        }
    }

    private var securitySection: some View {
        SettingsBlock(title: "Security") {
            Toggle(isOn: $requireCardUnlock) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Require Face ID for cards")
                        .font(.appFont(size: 14, weight: .semibold))
                    Text("Lock card balances until authenticated")
                        .font(.appFont(size: 12))
                        .foregroundStyle(Palette.secondary)
                }
            }
            .tint(Palette.primary)
            .onChange(of: requireCardUnlock) { _, newValue in
                onToggleCardLock(newValue)
            }

            Button {
                showPasswordReset = true
            } label: {
                SettingsButtonRow(title: "Change Password", subtitle: "Update your credentials")
            }
        }
    }

    private var dataSection: some View {
        SettingsBlock(title: "Data & Sync") {
            Button {
                exportData()
            } label: {
                SettingsButtonRow(title: "Export Data", subtitle: "Save as PDF to Files")
            }

            Button {
                syncNow()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.appFont(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Now")
                            .font(.appFont(size: 15, weight: .semibold))
                        Text("Refresh all data from server")
                            .font(.appFont(size: 11))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.primary)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var categoriesSection: some View {
        SettingsBlock(title: "Categories") {
            if categories.isEmpty {
                Text("No categories yet")
                    .font(.appFont(size: 13))
                    .foregroundStyle(Palette.secondary)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Text(category)
                            .font(.appFont(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .minimalSurface(cornerRadius: 12, fill: Palette.cardAlt)
                    }
                }
            }

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
                Text("Clear All Categories")
                    .font(.appFont(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt, stroke: Palette.danger.opacity(0.3))
            }
            .padding(.top, 4)
        }
    }

    private var supportSection: some View {
        SettingsBlock(title: "Help & Support") {
            Button {
                showHelpCenter = true
            } label: {
                SettingsButtonRow(title: "Help Center", subtitle: "FAQs, guides, and how-to")
            }

            Button {
                showTickets = true
            } label: {
                SettingsButtonRow(title: "Support", subtitle: "Tickets and messages")
            }

            Button {
                rateApp()
            } label: {
                SettingsButtonRow(title: "Rate App", subtitle: "Share your feedback")
            }
        }
    }

    private var aboutSection: some View {
        SettingsBlock(title: "About") {
            SettingsLine(label: "Version", value: appVersion)

            Button {
                showTerms = true
            } label: {
                SettingsButtonRow(title: "Terms of Service", subtitle: "Read the terms")
            }

            Button {
                showPrivacy = true
            } label: {
                SettingsButtonRow(title: "Privacy Policy", subtitle: "How we protect data")
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                session.logout()
            } label: {
                Text("Log Out")
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete Account")
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .minimalSurface(cornerRadius: 16, fill: Palette.danger, stroke: Palette.danger)
            }
        }
    }

    private func handlePendingSupportTicket() {
        guard !pendingSupportTicketId.isEmpty else { return }
        showTickets = true
    }

    private func exportData() {
        guard let url = PDFExporter.export(transactions: transactions, cards: cards, user: session.user) else { return }
        exportItem = ExportFileItem(url: url)
    }

    private func syncNow() {
        onSyncNow()
    }

    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id\(Bundle.main.bundleIdentifier ?? "")") {
            UIApplication.shared.open(url)
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
        We collect information you provide when creating an account, such as your name and email. We also collect transaction and card metadata you add to the app.

        2. HOW WE USE INFORMATION
        We use your information to provide and improve the service, personalize insights, and communicate with you about updates.

        3. DATA SECURITY
        We implement security measures to protect your data, including encryption and secure storage.

        4. DATA SHARING
        We do not sell your personal data. We may share data with service providers necessary to operate the app.

        5. USER RIGHTS
        You can request deletion of your data at any time through the app settings.

        6. CONTACT
        For questions about this policy, contact support through the app.
        """
    }
}

private struct SettingsBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appFont(size: 13, weight: .semibold))
                .foregroundStyle(Palette.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .minimalSurface(cornerRadius: 18)
        }
    }
}

private struct SettingsLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.appFont(size: 14, weight: .semibold))
            Spacer()
            Text(value)
                .font(.appFont(size: 13))
                .foregroundStyle(Palette.secondary)
        }
    }
}

private struct SettingsButtonRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appFont(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.appFont(size: 12))
                    .foregroundStyle(Palette.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.appFont(size: 12, weight: .semibold))
                .foregroundStyle(Palette.tertiary)
        }
    }
}

private struct ExportFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PDFExporter {
    static func export(transactions: [Transaction], cards: [CardInfo], user: UserProfile?) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let lineHeight: CGFloat = 20

        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y = margin
            let maxY = pageHeight - margin

            func drawText(_ text: String, font: UIFont, color: UIColor = .black) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let rect = CGRect(x: margin, y: y, width: pageWidth - 2 * margin, height: lineHeight * 2)
                text.draw(in: rect, withAttributes: attributes)
                y += lineHeight
            }

            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let headingFont = UIFont.boldSystemFont(ofSize: 14)
            let bodyFont = UIFont.systemFont(ofSize: 11)

            drawText("TrackIt – Data Export", font: titleFont)
            drawText("Generated \(Date().formatted(date: .abbreviated, time: .shortened))", font: bodyFont)
            y += 10

            if let user = user {
                drawText("Account: \(user.firstName) \(user.lastName) (\(user.email))", font: bodyFont)
                y += 8
            }

            y += 10
            drawText("Summary", font: headingFont)
            drawText("Cards: \(cards.count)  |  Transactions: \(transactions.count)", font: bodyFont)
            y += 16

            drawText("Cards", font: headingFont)
            for card in cards.prefix(20) {
                let bal = card.balance ?? 0
                drawText("• \(card.nickname.isEmpty ? "Card" : card.nickname): \(bal.formatted(.currency(code: AppConstants.Currency.code)))", font: bodyFont)
                if y > maxY { context.beginPage(); y = margin }
            }
            y += 12

            drawText("Transactions (latest first)", font: headingFont)
            let sorted = transactions.sorted { $0.date > $1.date }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            for tx in sorted.prefix(100) {
                let kindStr = tx.kind == .income ? "+" : "-"
                let amountStr = "\(kindStr)\(abs(tx.amount).formatted(.currency(code: AppConstants.Currency.code)))"
                let dateStr = dateFormatter.string(from: tx.date)
                drawText("\(dateStr)  \(tx.category)  \(amountStr)", font: bodyFont)
                if y > maxY { context.beginPage(); y = margin }
            }
            if transactions.count > 100 {
                drawText("… and \(transactions.count - 100) more transactions", font: bodyFont)
            }
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "TrackIt_Export_\(Date().timeIntervalSince1970).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
