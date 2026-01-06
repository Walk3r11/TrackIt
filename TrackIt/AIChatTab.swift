import SwiftUI

struct AIChatTab: View {
    @EnvironmentObject private var session: SessionManager
    @State private var messages: [ChatMessage] = []
    @State private var chatHistories: [ChatHistory] = []
    @State private var currentChatId: UUID?
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showHistory: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var activeStreamingTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                headerSection
                
                if showHistory {
                    historyView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    chatView
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            loadChatHistories()
        }
        .task(id: currentChatId) {
            guard !isLoading, let chatId = currentChatId else { return }
            await loadChat(chatId)
        }
        .onDisappear {
            activeStreamingTask?.cancel()
            saveCurrentChat()
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                        Text("AI Assistant")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.primary)
                        Text("Your financial assistant")
                            .font(.subheadline)
                            .foregroundColor(Palette.secondary)
                    }
            
                    Spacer()
            
            if !showHistory {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentChatId = nil
                        messages = []
                        SecureStore.delete(key: "currentChat")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Palette.accent)
                        .symbolEffect(.bounce, value: currentChatId == nil)
                }
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showHistory.toggle()
                }
            } label: {
                Image(systemName: showHistory ? "xmark.circle.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Palette.accent)
                    .symbolEffect(.bounce, value: showHistory)
            }
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
                
    private var chatView: some View {
        VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                    LazyVStack(spacing: 16) {
                            if messages.isEmpty {
                            emptyStateView
                                .padding(.top, 60)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        ForEach(messages.suffix(30), id: \.id) { message in
                            MessageBubble(message: message, isStreaming: isLoading && message.id == messages.last?.id && message.role == "assistant")
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(Palette.accent)
                                    Text("Thinking...")
                                        .font(.subheadline)
                                        .foregroundColor(Palette.secondary)
                                }
                                .padding()
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)
                    .padding(.vertical, 20)
                }
                .onChange(of: isLoading) { _, newValue in
                    if !newValue, let lastMessage = messages.last {
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
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
            
            inputSection
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Palette.accent)
                .symbolEffect(.pulse, options: .repeating)
            
            Text("Ask me anything about your finances!")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Palette.primary)
            
            Text("I can help you understand your spending, track your goals, and provide financial advice.")
                .font(.subheadline)
                                .foregroundColor(Palette.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Palette.stroke)
            
                HStack(spacing: 12) {
                    TextField("Ask about your finances...", text: $inputText, axis: .vertical)
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
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
                        .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isInputFocused ? Palette.accent.opacity(0.5) : Palette.stroke, lineWidth: isInputFocused ? 2 : 1)
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInputFocused)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .disabled(isLoading)
                    .onSubmit {
                        sendMessage()
                        }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                                ? LinearGradient(colors: [Palette.secondary.opacity(0.4), Palette.secondary.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Palette.accentAlt, Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .scaleEffect(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: inputText.isEmpty)
                }
                .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 16)
        }
    }
    
    private var historyView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if chatHistories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(Palette.secondary)
                        Text("No previous chats")
                            .font(.headline)
                            .foregroundColor(Palette.primary)
                        Text("Start a conversation to create your first chat")
                            .font(.subheadline)
                            .foregroundColor(Palette.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(Array(chatHistories.enumerated()), id: \.element.id) { index, history in
                        HistoryRow(history: history, isSelected: currentChatId == history.id) {
                            currentChatId = history.id
                            showHistory = false
                        } onDelete: {
                            deleteChat(history.id)
                        }
                    }
                }
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 20)
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        
        activeStreamingTask?.cancel()
        activeStreamingTask = nil
        isInputFocused = false
        
        guard let userId = session.user?.id, let token = session.token else {
            errorMessage = "Authentication required"
            return
        }
        
        if currentChatId == nil {
            currentChatId = UUID()
        }
        
        let userMessage = ChatMessage(role: "user", content: text, timestamp: Date())
        messages.append(userMessage)
        
        if messages.count > 30 {
            messages.removeFirst(messages.count - 30)
        }
        
        inputText = ""
        errorMessage = nil
        isLoading = true
        
        let apiMessages = messages
            .filter { !$0.content.isEmpty }
            .map { APIClient.GroqMessage(role: $0.role, content: $0.content) }
        
        let assistantMessage = ChatMessage(role: "assistant", content: "", timestamp: Date())
        let assistantMessageId = assistantMessage.id
        messages.append(assistantMessage)
        
        activeStreamingTask = Task {
            do {
                var accumulatedContent = ""
                let stream = APIClient.shared.chatWithGroqStreaming(token: token, messages: apiMessages, userId: userId)
                
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    accumulatedContent += chunk
                    
                    await MainActor.run {
                        if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                            messages[index].content = accumulatedContent
                        }
                    }
                }
                
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        messages[index].content = accumulatedContent.isEmpty ? "No response received" : accumulatedContent
                    } else {
                        let finalMessage = ChatMessage(role: "assistant", content: accumulatedContent.isEmpty ? "No response received" : accumulatedContent, timestamp: Date())
                        messages.append(finalMessage)
                    }
                    isLoading = false
                    saveCurrentChat()
                    saveChatToServer()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        let errorMsg = error.localizedDescription
                        messages[index].content = "Error: \(errorMsg)"
                        errorMessage = errorMsg
                    } else {
                        let errorMessage = ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)", timestamp: Date())
                        messages.append(errorMessage)
                    }
                }
            }
        }
    }
    
    private func loadChatHistories() {
        if let stored: [ChatHistory] = SecureStore.load([ChatHistory].self, key: "chatHistories") {
            chatHistories = Array(stored.sorted { $0.updatedAt > $1.updatedAt }.prefix(50))
        }
    }
    
    private func loadChat(_ chatId: UUID) async {
        guard !isLoading else { return }
        
        if let existing = chatHistories.first(where: { $0.id == chatId }) {
            await MainActor.run {
                if !isLoading {
                    messages = Array(existing.messages.suffix(30))
                }
            }
            return
        }
        
        guard let userId = session.user?.id, let token = session.token else { return }
        
        do {
            let serverMessages = try await APIClient.shared.fetchChatHistory(userId: userId, token: token)
            await MainActor.run {
                if !isLoading {
                    let limited = Array(serverMessages.suffix(30))
                    messages = limited
                    
                    if !limited.isEmpty {
                        let title = limited.first(where: { $0.role == "user" })?.content.prefix(50) ?? "New Chat"
                        let history = ChatHistory(id: chatId, title: String(title), messages: limited, updatedAt: Date())
                        
                        if let index = chatHistories.firstIndex(where: { $0.id == chatId }) {
                            chatHistories[index] = history
                        } else {
                            chatHistories.insert(history, at: 0)
                        }
                        
                        if chatHistories.count > 50 {
                            chatHistories = Array(chatHistories.prefix(50))
                        }
                        
                        saveChatHistories()
                    }
                }
            }
        } catch {
            if let existing = chatHistories.first(where: { $0.id == chatId }) {
                await MainActor.run {
                    if !isLoading {
                        messages = Array(existing.messages.suffix(30))
                    }
                }
            }
        }
    }
    
    private func deleteChat(_ historyId: UUID) {
        chatHistories.removeAll { $0.id == historyId }
        if currentChatId == historyId {
            currentChatId = nil
            messages = []
        }
        saveChatHistories()
        
        guard let userId = session.user?.id, let token = session.token else { return }
        
        Task {
            try? await APIClient.shared.deleteChatHistory(userId: userId, token: token, chatId: historyId.uuidString)
            await reloadChats()
        }
    }
    
    private func reloadChats() async {
        guard let userId = session.user?.id, let token = session.token else { return }
        
        do {
            let serverMessages = try await APIClient.shared.fetchChatHistory(userId: userId, token: token)
            await MainActor.run {
                if !serverMessages.isEmpty {
                    let title = serverMessages.first(where: { $0.role == "user" })?.content.prefix(50) ?? "New Chat"
                    let history = ChatHistory(title: String(title), messages: serverMessages)
                    
                    if let index = chatHistories.firstIndex(where: { $0.id == history.id }) {
                        chatHistories[index] = history
                    } else {
                        chatHistories.insert(history, at: 0)
                    }
                    
                    chatHistories = Array(chatHistories.sorted { $0.updatedAt > $1.updatedAt }.prefix(50))
                    saveChatHistories()
                }
            }
        } catch {}
    }
    
    private func saveCurrentChat() {
        guard !messages.isEmpty, let chatId = currentChatId else {
            if currentChatId == nil {
                SecureStore.delete(key: "currentChat")
            }
            return
        }
        
        SecureStore.save(messages, key: "currentChat")
        
        let title = messages.first(where: { $0.role == "user" })?.content.prefix(50) ?? "New Chat"
        let history = ChatHistory(id: chatId, title: String(title), messages: messages, updatedAt: Date())
        
        if let index = chatHistories.firstIndex(where: { $0.id == chatId }) {
            chatHistories[index] = history
        } else {
            chatHistories.insert(history, at: 0)
        }
        
        if chatHistories.count > 50 {
            chatHistories = Array(chatHistories.prefix(50))
        }
        
        saveChatHistories()
    }
    
    private func saveChatHistories() {
        SecureStore.save(chatHistories, key: "chatHistories")
    }
    
    private func saveChatToServer() {
        guard let userId = session.user?.id, let token = session.token, !messages.isEmpty, let chatId = currentChatId else { return }
        
        Task {
            try? await APIClient.shared.saveChatHistory(userId: userId, chatId: chatId.uuidString, messages: messages, token: token)
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isStreaming: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == "user" {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                Text(formatBoldText(message.content.isEmpty ? " " : message.content))
                    .font(.body)
                    .foregroundColor(message.role == "user" ? .white : Palette.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(Self.timeFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor((message.role == "user" ? Color.white : Palette.secondary).opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: message.role == "user"
                        ? [Palette.accentAlt, Palette.accent]
                        : [Palette.card, Palette.cardAlt],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(message.role == "user" ? .white.opacity(0.2) : Palette.stroke, lineWidth: 1)
            )
            
            if message.role == "assistant" {
                Spacer(minLength: 40)
            }
        }
    }
    
    private func formatBoldText(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        let doubleBoldPattern = "\\*\\*([^*]+?)\\*\\*"
        if let regex = try? NSRegularExpression(pattern: doubleBoldPattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range
                    let contentRange = match.range(at: 1)
                    
                    if let fullAttrRange = Range(fullRange, in: result),
                       let contentText = Range(contentRange, in: text) {
                        let boldText = String(text[contentText])
                        result.replaceSubrange(fullAttrRange, with: AttributedString(boldText))
                        
                        if let newRange = Range(contentRange, in: result) {
                            result[newRange].font = .body.bold()
                        }
                    }
                }
            }
        }
        
        let singleBoldPattern = "\\*([^*\\n]+?)\\*"
        if let regex = try? NSRegularExpression(pattern: singleBoldPattern, options: []) {
            let nsString = text as NSString
            let allMatches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            let filteredMatches = allMatches.filter { match in
                if match.range.location > 0 && match.range.location + match.range.length < nsString.length {
                    let beforeChar = nsString.substring(with: NSRange(location: match.range.location - 1, length: 1))
                    let afterChar = nsString.substring(with: NSRange(location: match.range.location + match.range.length, length: 1))
                    return beforeChar != "*" && afterChar != "*"
                }
                return true
            }
            
            for match in filteredMatches.reversed() {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range
                    let contentRange = match.range(at: 1)
                    
                    if let fullAttrRange = Range(fullRange, in: result),
                       let contentText = Range(contentRange, in: text) {
                        let boldText = String(text[contentText])
                        result.replaceSubrange(fullAttrRange, with: AttributedString(boldText))
                        
                        if let newRange = Range(contentRange, in: result) {
                            result[newRange].font = .body.bold()
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct HistoryRow: View {
    let history: ChatHistory
    let isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Palette.accentAlt.opacity(0.3), Palette.accent.opacity(0.2)]
                                : [Palette.card, Palette.cardAlt],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isSelected ? Palette.accent : Palette.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(history.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.primary)
                        .lineLimit(1)
                    Text(Self.dateFormatter.string(from: history.updatedAt))
                        .font(.caption)
                        .foregroundColor(Palette.secondary)
                }
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Palette.danger.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
                    .stroke(isSelected ? Palette.accent.opacity(0.4) : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
