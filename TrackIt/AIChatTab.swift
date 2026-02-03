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
                Text("Assistant")
                    .font(.appFont(size: 26, weight: .semibold))
                    .foregroundColor(Palette.primary)
                Text("Ask about spending, budgets, and goals.")
                    .font(.appFont(size: 13))
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
                    Image(systemName: "plus")
                        .font(.appFont(size: 16, weight: .semibold))
                        .foregroundColor(Palette.primary)
                        .frame(width: 36, height: 36)
                        .minimalSurface(cornerRadius: 12, fill: Palette.cardAlt)
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showHistory.toggle()
                }
            } label: {
                Image(systemName: showHistory ? "xmark" : "clock.arrow.circlepath")
                    .font(.appFont(size: 16, weight: .semibold))
                    .foregroundColor(Palette.primary)
                    .frame(width: 36, height: 36)
                    .minimalSurface(cornerRadius: 12, fill: Palette.cardAlt)
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
                    LazyVStack(spacing: 10) {
                        if messages.isEmpty {
                            emptyStateView
                                .padding(.top, 60)
                                .padding(.horizontal, LayoutMetrics.horizontalPadding)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        ForEach(messages.suffix(30), id: \.id) { message in
                            MessageBubble(
                                message: message,
                                isStreaming: isLoading && message.id == messages.last?.id && message.role == "assistant"
                            )
                            .id(message.id)
                        }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(Palette.primary)
                                    .scaleEffect(0.9)
                                Text("Thinking...")
                                    .font(.appFont(size: 13, weight: .medium))
                                    .foregroundColor(Palette.secondary)
                            }
                            .padding(.leading, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.vertical, 16)
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
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
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
        VStack(spacing: 14) {
            Circle()
                .fill(Palette.cardAlt)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.appFont(size: 26, weight: .semibold))
                        .foregroundColor(Palette.primary)
                )

            Text("Start a new conversation")
                .font(.appFont(size: 18, weight: .semibold))
                .foregroundColor(Palette.primary)

            Text("Ask about spending trends, monthly budgets, or savings goals.")
                .font(.appFont(size: 13))
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
                    .font(.appFont(size: 15))
                    .foregroundColor(Palette.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .disabled(isLoading)
                    .onSubmit {
                        sendMessage()
                    }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.appFont(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? Palette.secondary.opacity(0.3) : Palette.primary)
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, LayoutMetrics.horizontalPadding)
            .padding(.vertical, 14)
            .background(Palette.background.opacity(0.95))
        }
    }

    private var historyView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if chatHistories.isEmpty {
                    VStack(spacing: 12) {
                        Text("No previous chats")
                            .font(.appFont(size: 16, weight: .semibold))
                        Text("Start a conversation to create your first thread.")
                            .font(.appFont(size: 13))
                            .foregroundColor(Palette.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(Array(chatHistories.enumerated()), id: \.element.id) { _, history in
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
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
                if message.content.contains("|") && message.content.contains("---") {
                    TableView(content: message.content)
                } else {
                    Text(formatBoldText(message.content.isEmpty ? " " : message.content))
                        .font(.appFont(size: 15))
                        .foregroundColor(message.role == "user" ? .white : Palette.primary)
                        .multilineTextAlignment(message.role == "user" ? .trailing : .leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                }

                Text(Self.timeFormatter.string(from: message.timestamp))
                    .font(.appFont(size: 10, weight: .medium))
                    .foregroundColor(Palette.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.role == "user" ? Palette.primary : Palette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: message.role == "user" ? 0 : 1)
                    )
            )
            .frame(maxWidth: 300, alignment: message.role == "user" ? .trailing : .leading)

            if message.role == "assistant" {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, LayoutMetrics.horizontalPadding)
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

private struct TableView: View {
    let content: String

    var body: some View {
        let tableData = parseTable(content)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(tableData.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        TableCell(
                            text: cell.trimmingCharacters(in: .whitespaces),
                            isHeader: rowIndex == 0
                        )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
    }

    private func parseTable(_ text: String) -> [[String]] {
        let lines = text.components(separatedBy: .newlines)
        var rows: [[String]] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("---") || trimmed.allSatisfy({ $0 == "-" || $0 == "|" || $0 == " " }) {
                continue
            }

            let cells = trimmed
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        return rows
    }
}

private struct TableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(boldedText(text, baseWeight: isHeader ? .semibold : .regular, boldWeight: .bold))
            .font(.appFont(size: 12, weight: isHeader ? .semibold : .regular))
            .foregroundColor(Palette.primary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, isHeader ? 10 : 8)
            .background(isHeader ? Palette.cardAlt.opacity(0.7) : Color.white.opacity(0.001))
            .overlay(
                Rectangle()
                    .stroke(Palette.stroke.opacity(0.8), lineWidth: 0.5)
            )
    }

    private func boldedText(_ raw: String, baseWeight: Font.Weight, boldWeight: Font.Weight) -> AttributedString {
        let pattern = "\\*\\*([^*]+?)\\*\\*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return AttributedString(raw)
        }

        let nsString = raw as NSString
        let matches = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: nsString.length))
        var result = AttributedString("")
        var lastIndex = raw.startIndex

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let fullRange = Range(match.range, in: raw),
                  let contentRange = Range(match.range(at: 1), in: raw) else { continue }

            if lastIndex < fullRange.lowerBound {
                let normalText = String(raw[lastIndex..<fullRange.lowerBound])
                var normal = AttributedString(normalText)
                normal.font = .appFont(size: 12, weight: baseWeight)
                result.append(normal)
            }

            let boldText = String(raw[contentRange])
            var bold = AttributedString(boldText)
            bold.font = .appFont(size: 12, weight: boldWeight)
            result.append(bold)

            lastIndex = fullRange.upperBound
        }

        if lastIndex < raw.endIndex {
            let tail = String(raw[lastIndex...])
            var normal = AttributedString(tail)
            normal.font = .appFont(size: 12, weight: baseWeight)
            result.append(normal)
        }

        return result
    }
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
                    .fill(isSelected ? Palette.primary.opacity(0.15) : Palette.cardAlt)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.appFont(size: 16, weight: .medium))
                            .foregroundColor(Palette.primary)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(history.title)
                        .font(.appFont(size: 14, weight: .semibold))
                        .foregroundColor(Palette.primary)
                        .lineLimit(1)
                    Text(Self.dateFormatter.string(from: history.updatedAt))
                        .font(.appFont(size: 11))
                        .foregroundColor(Palette.secondary)
                }

                Spacer()

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.appFont(size: 13, weight: .medium))
                        .foregroundColor(Palette.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .minimalSurface(cornerRadius: 18, fill: isSelected ? Palette.cardAlt : Palette.card)
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
