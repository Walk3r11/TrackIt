import SwiftUI
import Combine

struct TicketsTab: View {
    @Binding var tickets: [SupportTicket]
    @Binding var showNewTicket: Bool
    @State private var selectedTicket: SupportTicket?
    @EnvironmentObject private var session: SessionManager
    var onTicketsChanged: (() -> Void)?

    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if tickets.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(tickets) { ticket in
                                Button {
                                    selectedTicket = ticket
                                } label: {
                                    TicketRow(ticket: ticket)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketChatView(ticket: ticket) { newStatus in
                if let index = tickets.firstIndex(where: { $0.id == ticket.id }) {
                    var updatedTicket = tickets[index]
                    updatedTicket.status = newStatus
                    tickets[index] = updatedTicket
                    SecureStore.save(tickets, key: "supportTickets")
                    onTicketsChanged?()
                }
            }
            .environmentObject(session)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Support")
                    .font(.appFont(size: 26, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Text("Your requests and conversation history")
                    .font(.appFont(size: 13))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            Button {
                showNewTicket = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("New")
                        .font(.appFont(size: 13, weight: .semibold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .minimalSurface(cornerRadius: 16, fill: Palette.primary, stroke: Palette.primary)
                .foregroundColor(.white)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No tickets yet")
                .font(.appFont(size: 16, weight: .semibold))
            Text("Create a ticket to reach support.")
                .font(.appFont(size: 13))
                .foregroundStyle(Palette.secondary)
        }
        .padding(16)
        .minimalSurface(cornerRadius: 18)
    }
}

private struct TicketRow: View {
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
    @State private var websocketCancellable: AnyCancellable?
    @AppStorage("activeTicketId") private var activeTicketId = ""
    @AppStorage("hasUnreadSupportNotification") private var hasUnreadSupportNotification = false
    @AppStorage("lastSupportNotificationId") private var lastSupportNotificationId = ""
    @State private var scrollToBottomToken = 0
    @State private var liveMessagesTask: Task<Void, Never>?
    @State private var isRefreshingMessages = false
    @State private var ticketStatus: SupportTicket.Status
    @State private var isClosingTicket = false
    var onTicketStatusChanged: ((SupportTicket.Status) -> Void)?

    private static var persistedMessages: [String: [APIClient.TicketMessage]] = [:]

    init(ticket: SupportTicket, onTicketStatusChanged: ((SupportTicket.Status) -> Void)? = nil) {
        self.ticket = ticket
        self.onTicketStatusChanged = onTicketStatusChanged
        _ticketStatus = State(initialValue: ticket.status)
    }

    private var currentTicketStatus: SupportTicket.Status {
        ticketStatus
    }

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
                                    VStack(spacing: 12) {
                                        Text("No messages yet")
                                            .font(.appFont(size: 16, weight: .semibold))
                                            .foregroundColor(Palette.primary)
                                        Text("Start the conversation")
                                            .font(.appFont(size: 13))
                                            .foregroundColor(Palette.secondary)
                                    }
                                    .padding(.vertical, 40)
                                }

                                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                                    TicketChatBubble(message: message, isUser: message.senderType == "user")
                                        .id(message.id)
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
                        .onChange(of: scrollToBottomToken) { _, _ in
                            if let lastMessage = messages.last {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onTapGesture {
                            isInputFocused = false
                        }
                    }

                    if ticketStatus == .closed {
                        HStack {
                            Spacer()
                            Text("This ticket is closed")
                                .font(.appFont(size: 13, weight: .semibold))
                                .foregroundColor(Palette.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        .background(Palette.background)
                    } else {
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $inputText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
                                .foregroundColor(Palette.primary)
                                .focused($isInputFocused)
                                .toolbar { }

                            Button {
                                sendMessage()
                            } label: {
                                ZStack {
                                    if isSending {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.appFont(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending ? Palette.secondary.opacity(0.3) : Palette.primary)
                                )
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                        }
                        .padding(.horizontal, LayoutMetrics.horizontalPadding)
                        .padding(.vertical, 12)
                        .background(Palette.background)
                    }
                }
            }
            .navigationTitle(ticket.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if ticketStatus != .closed {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            closeTicket()
                        } label: {
                            if isClosingTicket {
                                ProgressView()
                                    .tint(Palette.primary)
                            } else {
                                Text("Close Ticket")
                                    .font(.appFont(size: 14, weight: .semibold))
                                    .foregroundColor(Palette.danger)
                            }
                        }
                        .disabled(isClosingTicket)
                    }
                }
            }
            .task {
                await loadMessages()
                await refreshTicketStatus()
                setupWebSocket()
                startLiveMessagesLoop()
                await markReadIfNeeded()
                await MainActor.run {
                    scrollToBottomToken += 1
                }
            }
            .onDisappear {
                WebSocketManager.shared.disconnect()
                websocketCancellable?.cancel()
                websocketCancellable = nil
                stopLiveMessagesLoop()
                if activeTicketId == ticket.id.uuidString {
                    activeTicketId = ""
                }
            }
            .onAppear {
                activeTicketId = ticket.id.uuidString
            }
        }
    }

    private func setupWebSocket() {
        guard let token = session.token, let userId = session.user?.id else {
            return
        }

        WebSocketManager.shared.disconnect()
        websocketCancellable?.cancel()

        WebSocketManager.shared.connect(
            token: token,
            userId: userId,
            supportUserId: nil,
            streamType: .ticketMessages,
            ticketId: ticket.id.uuidString
        )

        websocketCancellable = WebSocketManager.shared.messages
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { message in
                if message.type == "status", let statusString = message.data?["status"]?.value as? String,
                   let newStatus = SupportTicket.Status(rawValue: statusString.lowercased()) {
                    ticketStatus = newStatus
                    onTicketStatusChanged?(newStatus)
                } else if let data = message.data?["message"]?.value as? [String: Any],
                      let newMessage = decodeTicketMessage(from: data) {
                    if !messages.contains(where: { $0.id == newMessage.id }) {
                        messages.append(newMessage)
                        persistMessages()
                        if newMessage.senderType == "support" {
                            Task { await markReadIfNeeded() }
                        }
                    }
                }
            })
    }

    private func decodeTicketMessage(from data: [String: Any]) -> APIClient.TicketMessage? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let message = try? JSONDecoder().decode(APIClient.TicketMessage.self, from: jsonData) else {
            return nil
        }
        return message
    }

    private static func storageKey(ticketId: String) -> String {
        "ticketMessages_\(ticketId)"
    }

    static func persistMessagesLocally(ticketId: String, messages: [APIClient.TicketMessage]) {
        persistedMessages[ticketId] = messages
        SecureStore.save(messages, key: storageKey(ticketId: ticketId))
    }

    static func appendMessageToCache(ticketId: String, message: APIClient.TicketMessage) {
        var list = persistedMessages[ticketId] ?? (SecureStore.load([APIClient.TicketMessage].self, key: storageKey(ticketId: ticketId)) ?? [])
        if !list.contains(where: { $0.id == message.id }) {
            list.append(message)
            persistedMessages[ticketId] = list
            SecureStore.save(list, key: storageKey(ticketId: ticketId))
        }
    }

    private func loadMessages() async {
        let ticketId = ticket.id.uuidString

        guard let token = session.token else {
            if let diskCached: [APIClient.TicketMessage] = SecureStore.load([APIClient.TicketMessage].self, key: Self.storageKey(ticketId: ticketId)) {
                await MainActor.run {
                    messages = diskCached
                    TicketChatView.persistedMessages[ticketId] = diskCached
                }
            } else if let memoryCached = TicketChatView.persistedMessages[ticketId] {
                await MainActor.run {
                    messages = memoryCached
                }
            }
            return
        }

        var cachedMessages: [APIClient.TicketMessage] = []
        if let diskCached: [APIClient.TicketMessage] = SecureStore.load([APIClient.TicketMessage].self, key: Self.storageKey(ticketId: ticketId)) {
            cachedMessages = diskCached
        } else if let memoryCached = TicketChatView.persistedMessages[ticketId] {
            cachedMessages = memoryCached
        }

        if !cachedMessages.isEmpty {
            await MainActor.run {
                messages = cachedMessages
                TicketChatView.persistedMessages[ticketId] = cachedMessages
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await APIClient.shared.fetchTicketMessages(ticketId: ticketId, token: token)
            await MainActor.run {
                if fetched.count >= messages.count {
                    messages = fetched
                    persistMessages()
                } else if !messages.isEmpty {
                    let fetchedIds = Set(fetched.map { $0.id })
                    let existingIds = Set(messages.map { $0.id })
                    if fetchedIds != existingIds {
                        messages = fetched
                        persistMessages()
                    }
                } else {
                    messages = fetched
                    persistMessages()
                }
            }
        } catch {
            await MainActor.run {
                if messages.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startLiveMessagesLoop() {
        guard liveMessagesTask == nil else { return }
        liveMessagesTask = Task {
            while !Task.isCancelled {
                await refreshMessages()
                try? await Task.sleep(nanoseconds: AppConstants.Refresh.ticketMessagesNanoseconds)
            }
        }
    }

    private func stopLiveMessagesLoop() {
        liveMessagesTask?.cancel()
        liveMessagesTask = nil
    }

    private func refreshMessages() async {
        guard let token = session.token else { return }
        let shouldRefresh = await MainActor.run { () -> Bool in
            if isRefreshingMessages { return false }
            isRefreshingMessages = true
            return true
        }
        guard shouldRefresh else { return }

        do {
            let fetched = try await APIClient.shared.fetchTicketMessages(ticketId: ticket.id.uuidString, token: token)
            await MainActor.run {
                if shouldReplaceMessages(with: fetched) {
                    messages = fetched
                    persistMessages()
                }
                isRefreshingMessages = false
            }
        } catch {
            await MainActor.run {
                isRefreshingMessages = false
            }
        }
    }

    private func shouldReplaceMessages(with fetched: [APIClient.TicketMessage]) -> Bool {
        if fetched.count != messages.count {
            return true
        }
        guard let lastFetched = fetched.last, let lastExisting = messages.last else {
            return !fetched.isEmpty || !messages.isEmpty
        }
        if lastFetched.id != lastExisting.id {
            return true
        }
        if lastFetched.readByUserAt != lastExisting.readByUserAt || lastFetched.readBySupportAt != lastExisting.readBySupportAt {
            return true
        }
        return false
    }

    private func markReadIfNeeded() async {
        guard let token = session.token else { return }
        do {
            try await APIClient.shared.markTicketMessagesRead(
                ticketId: ticket.id.uuidString,
                reader: "user",
                token: token
            )
            await MainActor.run {
                hasUnreadSupportNotification = false
                lastSupportNotificationId = ""
            }
        } catch {
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        guard let token = session.token else {
            errorMessage = "Authentication required"
            return
        }

        isSending = true
        inputText = ""

        Task {
            do {
                let newMessage = try await APIClient.shared.sendTicketMessage(
                    ticketId: ticket.id.uuidString,
                    content: trimmed,
                    token: token
                )

                await MainActor.run {
                    messages.append(newMessage)
                    persistMessages()
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }

    private func persistMessages() {
        let ticketId = ticket.id.uuidString
        TicketChatView.persistedMessages[ticketId] = messages
        SecureStore.save(messages, key: Self.storageKey(ticketId: ticketId))
    }

    private func refreshTicketStatus() async {
        guard let token = session.token else { return }
        do {
            let tickets = try await APIClient.shared.fetchTickets(userId: session.user?.id ?? "", token: token)
            if let updatedTicket = tickets.first(where: { $0.id == ticket.id }) {
                await MainActor.run {
                    if ticketStatus != updatedTicket.status {
                        ticketStatus = updatedTicket.status
                        onTicketStatusChanged?(updatedTicket.status)
                    }
                }
            }
        } catch {}
    }

    private func closeTicket() {
        guard !isClosingTicket, let token = session.token else { return }
        isClosingTicket = true

        Task {
            do {
                try await APIClient.shared.closeTicket(ticketId: ticket.id.uuidString, token: token)
                await MainActor.run {
                    ticketStatus = .closed
                    onTicketStatusChanged?(.closed)
                    isClosingTicket = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to close ticket: \(error.localizedDescription)"
                    isClosingTicket = false
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
                Spacer(minLength: 40)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.appFont(size: 14))
                    .foregroundColor(isUser ? .white : Palette.primary)
                    .multilineTextAlignment(isUser ? .trailing : .leading)

                Text(formattedTimestamp(message.createdAt))
                    .font(.appFont(size: 10, weight: .medium))
                    .foregroundColor(isUser ? Color.white.opacity(0.7) : Palette.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isUser ? Palette.primary : Palette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: isUser ? 0 : 1)
                    )
            )

            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }

    private func formattedTimestamp(_ value: String) -> String {
        if let date = Self.isoFormatter.date(from: value) {
            return Self.displayFormatter.string(from: date)
        }
        return value
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
