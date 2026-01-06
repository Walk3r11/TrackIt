import SwiftUI

struct TicketsTab: View {
    @Binding var tickets: [SupportTicket]
    @Binding var showNewTicket: Bool
    @State private var selectedTicket: SupportTicket?
    @EnvironmentObject private var session: SessionManager

    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Tickets")
                            .font(.largeTitle.bold())
                            .foregroundColor(Palette.primary)
                        Spacer()
                        Button {
                            showNewTicket = true
                        } label: {
                            Label("New", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Palette.accentAlt, in: Capsule())
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }

                    if tickets.isEmpty {
                        EmptyStateView(title: "No tickets", message: "Create a ticket to reach support.")
                            .glassCard(cornerRadius: 18, tint: [Palette.accentAlt, Palette.accent])
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
                                    .glassCard(cornerRadius: 18, tint: [Palette.cardAlt, Palette.accentAlt])
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .frame(maxWidth: LayoutMetrics.maxContentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                .padding(.vertical, 16)
            }
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketChatView(ticket: ticket)
                .environmentObject(session)
        }
    }
}

struct TicketChatView: View {
    let ticket: SupportTicket
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [APIClient.TicketMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    
    private static var persistedMessages: [String: [APIClient.TicketMessage]] = [:]
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                    .allowsHitTesting(false)
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if messages.isEmpty && !isLoading {
                                    VStack(spacing: 16) {
                                        Image(systemName: "message")
                                            .font(.system(size: 48))
                                            .foregroundColor(Palette.accent)
                                            .opacity(0.6)
                                        Text("No messages yet")
                                            .font(.headline)
                                            .foregroundColor(Palette.primary)
                                        Text("Start the conversation")
                                            .font(.subheadline)
                                            .foregroundColor(Palette.secondary)
                                    }
                                    .padding(.vertical, 40)
                                }
                                
                                ForEach(messages) { message in
                                    TicketChatBubble(message: message, isUser: message.senderType == "user")
                                        .id(message.id)
                                }
                                
                                if isSending {
                                    HStack {
                                        ProgressView()
                                            .tint(Palette.accent)
                                        Text("Sending...")
                                            .font(.subheadline)
                                            .foregroundColor(Palette.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, LayoutMetrics.horizontalPadding)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onTapGesture {
                            isInputFocused = false
                        }
                    }
                    
                    HStack(spacing: 12) {
                        TextField("Type a message...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Palette.mutedFill, in: RoundedRectangle(cornerRadius: 24))
                            .foregroundColor(Palette.primary)
                            .focused($isInputFocused)
                            .disabled(isSending)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        isInputFocused = false
                                    }
                                    .foregroundColor(Palette.accent)
                                }
                            }
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending ? Palette.secondary.opacity(0.5) : Palette.accent)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Palette.card.opacity(0.95), Palette.cardAlt.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationTitle(ticket.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadMessages()
            }
        }
    }
    
    private func loadMessages() async {
        guard let token = session.token, !token.isEmpty else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        if let persisted = Self.persistedMessages[ticket.id.uuidString] {
            await MainActor.run {
                messages = persisted
            }
        }
        
        do {
            let fetchedMessages = try await APIClient.shared.fetchTicketMessages(
                ticketId: ticket.id.uuidString,
                token: token
            )
            await MainActor.run {
                messages = fetchedMessages
                Self.persistedMessages[ticket.id.uuidString] = fetchedMessages
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load messages: \(error.localizedDescription)"
            }
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, let token = session.token, !token.isEmpty else { return }
        
        isInputFocused = false
        isSending = true
        errorMessage = nil
        
        let tempMessage = APIClient.TicketMessage(
            id: UUID().uuidString,
            ticketId: ticket.id.uuidString,
            userId: session.user?.id,
            senderType: "user",
            content: text,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(tempMessage)
        inputText = ""
        
        Task {
            do {
                let sentMessage = try await APIClient.shared.sendTicketMessage(
                    ticketId: ticket.id.uuidString,
                    content: text,
                    token: token
                )
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                        messages[index] = sentMessage
                    } else {
                        messages.append(sentMessage)
                    }
                    Self.persistedMessages[ticket.id.uuidString] = messages
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == tempMessage.id }
                    errorMessage = "Failed to send: \(error.localizedDescription)"
                    isSending = false
                }
            }
        }
    }
}

struct TicketChatBubble: View {
    let message: APIClient.TicketMessage
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : Palette.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                    .background(
                        LinearGradient(
                            colors: isUser 
                                ? [Palette.accentAlt, Palette.accent]
                                : [Palette.card, Palette.cardAlt],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isUser ? Palette.accent.opacity(0.3) : Palette.stroke, lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 6,
                        y: 3
                    )
            }
            
            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct SupportTicketSheet: View {
    var onSubmit: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var detail = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Subject")) {
                    TextField("Issue title", text: $subject)
                }
                Section(header: Text("Details")) {
                    TextField("Describe the issue", text: $detail, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(subject.trimmingCharacters(in: .whitespacesAndNewlines),
                                 detail.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
