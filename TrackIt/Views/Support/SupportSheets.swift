import SwiftUI

struct SupportTicketSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSubmit: (String, String) -> Void
    @State private var subject: String = ""
    @State private var detail: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Start a new support request")
                            .font(.appFont(size: 18, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.appFont(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                            TextField("Billing question", text: $subject)
                                .textInputAutocapitalization(.sentences)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Details")
                                .font(.appFont(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                            TextEditor(text: $detail)
                                .frame(minHeight: 160)
                                .padding(10)
                                .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)
                        }

                        Button {
                            let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedSubject.isEmpty, !trimmedDetail.isEmpty else { return }
                            onSubmit(trimmedSubject, trimmedDetail)
                            dismiss()
                        } label: {
                            Text("Send request")
                                .font(.appFont(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
                        }
                        .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct TicketsSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var tickets: [SupportTicket]
    @Binding var showNewTicket: Bool
    @Binding var isPresented: Bool
    @Binding var pendingTicketId: String
    @State private var selectedTicket: SupportTicket?
    @State private var showNewTicketSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if tickets.isEmpty {
                            Text("No tickets yet")
                                .font(.appFont(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .minimalSurface(cornerRadius: 16, fill: Palette.cardAlt)
                        } else {
                            ForEach(tickets) { ticket in
                                Button {
                                    selectedTicket = ticket
                                    pendingTicketId = ""
                                } label: {
                                    SupportTicketRow(ticket: ticket)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Support Tickets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("New") {
                        showNewTicketSheet = true
                    }
                }
            }
            .sheet(isPresented: $showNewTicketSheet) {
                SupportTicketSheet { subject, detail in
                    guard let userId = session.user?.id, let token = session.token else { return }
                    let ticket = SupportTicket(subject: subject, detail: detail)
                    let localId = ticket.id
                    tickets.insert(ticket, at: 0)
                    TicketChatView.seedInitialUserMessage(
                        ticketId: ticket.id.apiString,
                        userId: userId,
                        content: detail
                    )

                    Task {
                        do {
                            let created = try await APIClient.shared.createTicket(
                                userId: userId,
                                subject: subject,
                                initialMessage: detail,
                                token: token
                            )
                            let serverId = created.ticketId
                            let messages = try await APIClient.shared.fetchTicketMessages(
                                ticketId: serverId.apiString,
                                token: token
                            )
                            await MainActor.run {
                                if let index = tickets.firstIndex(where: { $0.id == localId }) {
                                    var synced = tickets[index]
                                    synced.id = serverId
                                    tickets[index] = synced
                                    if selectedTicket?.id == localId {
                                        selectedTicket = synced
                                    }
                                }
                                if pendingTicketId == localId.apiString {
                                    pendingTicketId = serverId.apiString
                                }
                                TicketChatView.migrateMessageCache(from: localId.apiString, to: serverId.apiString)
                                TicketChatView.persistMessagesLocally(ticketId: serverId.apiString, messages: messages)
                                SecureStore.save(tickets, key: "supportTickets")
                            }
                        } catch {
                            await MainActor.run {
                                tickets.removeAll { $0.id == localId }
                            }
                        }
                    }
                }
            }
            .onChange(of: showNewTicket) { _, newValue in
                if newValue {
                    showNewTicketSheet = true
                    showNewTicket = false
                }
            }
            .sheet(item: $selectedTicket) { ticket in
                TicketChatView(ticket: ticketBinding(for: ticket))
                    .environmentObject(session)
            }
            .onChange(of: isPresented) { _, isOpen in
                if isOpen {
                    Task { await syncTicketStatusesFromServer() }
                }
            }
            .onAppear {
                Task { await syncTicketStatusesFromServer() }
            }
        }
    }

    private func ticketBinding(for ticket: SupportTicket) -> Binding<SupportTicket> {
        Binding(
            get: {
                tickets.first(where: { $0.id == ticket.id }) ?? ticket
            },
            set: { newValue in
                if let index = tickets.firstIndex(where: { $0.id == newValue.id }) {
                    tickets[index] = newValue
                }
                if selectedTicket?.id == newValue.id {
                    selectedTicket = newValue
                }
                SecureStore.save(tickets, key: "supportTickets")
            }
        )
    }

    private func syncTicketStatusesFromServer() async {
        guard let userId = session.user?.id, let token = session.token else { return }
        do {
            let remote = try await APIClient.shared.fetchTickets(userId: userId, token: token)
            await MainActor.run {
                for serverTicket in remote {
                    _ = tickets.updateTicketStatus(id: serverTicket.id, to: serverTicket.status)
                }
                SecureStore.save(tickets, key: "supportTickets")
            }
        } catch {}
    }
}

struct ContactSupportSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var subject: String = ""
    @State private var detail: String = ""
    @State private var isSending = false
    @State private var status: String?

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Support")
                            .font(.appFont(size: 18, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.appFont(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                            TextField("App feedback", text: $subject)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.appFont(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                            TextEditor(text: $detail)
                                .frame(minHeight: 160)
                                .padding(10)
                                .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)
                        }

                        if let status {
                            Text(status)
                                .font(.appFont(size: 12))
                                .foregroundStyle(Palette.secondary)
                        }

                        Button {
                            send()
                        } label: {
                            HStack(spacing: 8) {
                                if isSending { ProgressView().tint(.white) }
                                Text("Send")
                                    .font(.appFont(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
                        }
                        .disabled(isSending || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Support")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send() {
        guard let userId = session.user?.id, let token = session.token else { return }
        let subjectText = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailText = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subjectText.isEmpty, !detailText.isEmpty else { return }

        isSending = true
        status = nil

        Task {
            do {
                _ = try await APIClient.shared.createTicket(
                    userId: userId,
                    subject: subjectText,
                    initialMessage: detailText,
                    token: token
                )
                await MainActor.run {
                    status = "Message sent. We'll reply soon."
                    isSending = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    status = "Could not send message. Try again."
                    isSending = false
                }
            }
        }
    }
}

struct PasswordResetSheet: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @State private var status: String?
    @State private var isSending = false

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Reset your password")
                        .font(.appFont(size: 18, weight: .semibold))

                    Text("We'll email you a secure reset link.")
                        .font(.appFont(size: 13))
                        .foregroundStyle(Palette.secondary)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .minimalSurface(cornerRadius: 14, fill: Palette.cardAlt)

                    if let status {
                        Text(status)
                            .font(.appFont(size: 12))
                            .foregroundStyle(Palette.secondary)
                    }

                    Button {
                        send()
                    } label: {
                        HStack(spacing: 8) {
                            if isSending { ProgressView().tint(.white) }
                            Text("Send reset link")
                                .font(.appFont(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
                    }
                    .disabled(isSending || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Password Reset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .onAppear {
                if email.isEmpty {
                    email = session.user?.email ?? ""
                }
            }
        }
    }

    private func send() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        isSending = true
        status = nil
        Task {
            do {
                try await APIClient.shared.requestPasswordReset(email: trimmed)
                await MainActor.run {
                    status = "Reset email sent."
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    status = "Could not send reset email."
                    isSending = false
                }
            }
        }
    }
}

struct HelpCenterSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Help Center")
                            .font(.appFont(size: 18, weight: .semibold))

                        HelpItem(title: "Track transactions", detail: "Use the + button on Home to add income or expenses. You can assign a category and card.")
                        HelpItem(title: "Manage cards", detail: "Add cards to track balances and set daily, weekly, or monthly spending limits. Tap Cards on Home or add from the quick actions.")
                        HelpItem(title: "Insights", detail: "Switch to the Insights tab to see charts, spending patterns, trends, and comparisons.")
                        HelpItem(title: "Security", detail: "In Settings, enable \"Require Face ID for cards\" to lock card details until you authenticate.")
                        HelpItem(title: "Export data", detail: "In Settings under Data & Sync, tap Export Data to save your transactions and cards as a PDF to Files.")
                        HelpItem(title: "Sync", detail: "Tap Sync Now in Settings to refresh all data from the server. Data also syncs when you open the app.")
                        HelpItem(title: "Support", detail: "Open Support in Settings to view your tickets and messages, or create a new request. We reply in the app.")
                        HelpItem(title: "Categories", detail: "Categories are created automatically when you add transactions. You can clear all in Settings if you start over.")
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

struct LegalSheet: View {
    let title: String
    let content: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    Text(content)
                        .font(.appFont(size: 13))
                        .foregroundStyle(Palette.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

private struct HelpItem: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appFont(size: 14, weight: .semibold))
            Text(detail)
                .font(.appFont(size: 12))
                .foregroundStyle(Palette.secondary)
        }
        .padding(14)
        .minimalSurface(cornerRadius: 16, fill: Palette.cardAlt)
    }
}

private struct SupportTicketRow: View {
    let ticket: SupportTicket

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ticket.status == .open ? Palette.success.opacity(0.15) : Palette.cardAlt)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "lifepreserver")
                        .font(.appFont(size: 16, weight: .semibold))
                        .foregroundColor(ticket.status == .open ? Palette.success : Palette.secondary)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(ticket.subject)
                    .font(.appFont(size: 14, weight: .semibold))
                    .foregroundColor(Palette.primary)
                Text(ticket.detail)
                    .font(.appFont(size: 11))
                    .foregroundColor(Palette.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(ticket.status.rawValue.capitalized)
                .font(.appFont(size: 11, weight: .semibold))
                .foregroundColor(ticket.status == .open ? Palette.success : Palette.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Palette.cardAlt)
                )
        }
        .padding(14)
        .minimalSurface(cornerRadius: 18)
    }
}
