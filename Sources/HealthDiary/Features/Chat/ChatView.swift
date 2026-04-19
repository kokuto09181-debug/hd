import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @Environment(\.modelContext) private var context
    @State private var showingNewChat = false

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    EmptyChatView { showingNewChat = true }
                } else {
                    threadList
                }
            }
            .navigationTitle("相談")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewChat = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView()
            }
        }
    }

    private var threadList: some View {
        List {
            ForEach(threads) { thread in
                NavigationLink {
                    ChatThreadView(thread: thread)
                } label: {
                    ChatThreadRow(thread: thread)
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { context.delete(threads[$0]) }
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyChatView: View {
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("AIに相談する")
                    .font(.title2.bold())
                Text("レシピのアレンジ、献立の相談\n残り物の活用など何でも聞けます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                SuggestionButton(text: "このレシピをヘルシーにしたい", systemImage: "leaf") { onNew() }
                SuggestionButton(text: "残り物で何か作れますか？", systemImage: "arrow.triangle.2.circlepath") { onNew() }
                SuggestionButton(text: "健康的な食生活のアドバイス", systemImage: "heart") { onNew() }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

private struct SuggestionButton: View {
    let text: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: systemImage)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thread Row

private struct ChatThreadRow: View {
    let thread: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(thread.title)
                    .font(.body)
                Spacer()
                Text(thread.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let last = thread.messages.last {
                Text(last.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - New Chat

struct NewChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContext: ChatContext = .free
    @State private var initialMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("相談の種類") {
                    Picker("", selection: $selectedContext) {
                        Text("レシピ相談").tag(ChatContext.recipe)
                        Text("献立相談").tag(ChatContext.mealPlan)
                        Text("残り物活用").tag(ChatContext.leftover)
                        Text("健康相談").tag(ChatContext.health)
                        Text("自由相談").tag(ChatContext.free)
                    }
                    .pickerStyle(.wheel)
                }

                Section("最初のメッセージ") {
                    TextField("何でも聞いてください", text: $initialMessage, axis: .vertical)
                        .lineLimit(4)
                }
            }
            .navigationTitle("新しい相談")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始") { startChat() }
                        .disabled(initialMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func startChat() {
        let title = initialMessage.prefix(30).description
        let thread = ChatThread(title: title, context: selectedContext)
        context.insert(thread)

        let userMsg = ChatMessage(role: .user, content: initialMessage)
        context.insert(userMsg)
        thread.messages.append(userMsg)

        dismiss()
    }
}

// MARK: - Thread View

struct ChatThreadView: View {
    @Bindable var thread: ChatThread
    @StateObject private var llm = LLMService.shared
    @Environment(\.modelContext) private var context
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    private var sortedMessages: [ChatMessage] {
        thread.messages.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if llm.isLoading {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: thread.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()
            inputBar
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await llm.loadModelIfNeeded() }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("メッセージを入力", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? .secondary : .tint)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || llm.isLoading)
        }
        .padding()
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""

        let userMsg = ChatMessage(role: .user, content: text)
        context.insert(userMsg)
        thread.messages.append(userMsg)
        thread.updatedAt = Date()

        Task {
            do {
                let llmContext = LLMContext.free
                let response = try await llm.generate(prompt: text, context: llmContext)
                let assistantMsg = ChatMessage(role: .assistant, content: response)
                context.insert(assistantMsg)
                thread.messages.append(assistantMsg)
                thread.updatedAt = Date()
            } catch {}
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = sortedMessages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - Message Components

private struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

private struct TypingIndicator: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.secondary)
                        .scaleEffect(dotScale[i])
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: dotScale[i])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 60)
        }
        .onAppear {
            for i in 0..<3 { dotScale[i] = 0.5 }
        }
    }
}
