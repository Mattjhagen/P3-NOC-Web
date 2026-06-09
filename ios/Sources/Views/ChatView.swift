import SwiftUI

struct ChatView: View {
    @Bindable var client: NOCClient
    
    @State private var activeConversationId: Int? = nil
    @State private var showHistorySheet = false
    @State private var showTuningSheet = false
    
    // Tuning Parameters
    @State private var selectedModel = "phi3:mini"
    @State private var temperature: Double = 0.7
    @State private var topP: Double = 0.9
    @State private var customDirective = ""
    
    @State private var typedMessage = ""
    @Namespace private var scrollSpace
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberTerminalBg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let convId = activeConversationId {
                        // Message List
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 32) {
                                    if client.messages.isEmpty {
                                        emptyChannelView()
                                    } else {
                                        ForEach(client.messages) { msg in
                                            messageRow(msg: msg)
                                                .id(msg.id)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 24)
                                .padding(.bottom, 120)
                            }
                            .onChange(of: client.messages.count) { _, _ in
                                if let lastId = client.messages.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: client.isStreamingChat) { _, isStreaming in
                                if isStreaming, let lastId = client.messages.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        
                        // Input Bar
                        inputBarView(conversationId: convId)
                    } else {
                        noConversationView()
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        showHistorySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                            Text("THREADS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.cyberBlue)
                    }
                    .sheet(isPresented: $showHistorySheet) {
                        historySheetView()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if activeConversationId != nil {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            showTuningSheet = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(showTuningActive ? .cyberGreen : .white)
                        }
                        .sheet(isPresented: $showTuningSheet) {
                            tuningSheetView()
                        }
                    }
                }
            }
            .toolbarBackground(Color.cyberTerminalBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                if activeConversationId == nil, let first = client.conversations.first {
                    selectConversation(first.id)
                }
            }
            .onChange(of: isFieldFocused) { _, focused in
                client.isInputFocused = focused
            }
        }
    }
    
    private var showTuningActive: Bool {
        temperature != 0.7 || topP != 0.9 || !customDirective.isEmpty
    }
    
    // --- Message Rendering Logic ---
    
    struct ParsedMessage {
        let thoughts: String?
        let content: String
    }
    
    private func parseMessage(_ rawContent: String) -> ParsedMessage {
        if let startRange = rawContent.range(of: "[THINKING]") {
            if let endRange = rawContent.range(of: "[/THINKING]") {
                let thoughts = String(rawContent[startRange.upperBound..<endRange.lowerBound])
                let remaining = String(rawContent[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return ParsedMessage(thoughts: thoughts, content: remaining)
            } else {
                let thoughts = String(rawContent[startRange.upperBound...])
                return ParsedMessage(thoughts: thoughts, content: "")
            }
        }
        return ParsedMessage(thoughts: nil, content: rawContent)
    }
    
    private func messageRow(msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        let parsed = parseMessage(msg.content)
        
        return VStack(alignment: .leading, spacing: 16) {
            if isUser {
                // User prompt is rendered oversized, light and clean (like perplexity query)
                Text(msg.content)
                    .font(.system(size: 24, weight: .light))
                    .tracking(-0.5)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Assistant response layout (flat tiles and panels)
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Sources referenced (Perplexity-style layout row)
                    if let sources = msg.sources, !sources.isEmpty {
                        sourcesView(sources: sources)
                    }
                    
                    // Thoughts Expandable Panel
                    if let thoughts = parsed.thoughts, !thoughts.isEmpty {
                        ThoughtsConsoleView(thoughts: thoughts, isStreaming: client.isStreamingChat && parsed.content.isEmpty)
                    }
                    
                    // Core Content
                    if !parsed.content.isEmpty {
                        Text(parsed.content)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                    } else if parsed.thoughts != nil && parsed.content.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.cyberGreen)
                            Text("SYNTHESIZING ANSWER MATRIX...")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                    } else if parsed.thoughts == nil && parsed.content.isEmpty {
                        TypingIndicatorView()
                    }
                    
                    // Suggestions Panel (Perplexity-style follow-ups)
                    if let suggestions = msg.suggestions, !suggestions.isEmpty, let convId = activeConversationId {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RELATED INQUIRIES:")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Color.white.opacity(0.35))
                                .padding(.top, 4)
                            
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    HapticManager.shared.impact(style: .medium)
                                    Task {
                                        await client.sendMessage(
                                            conversationId: convId,
                                            content: suggestion,
                                            model: selectedModel,
                                            temperature: temperature,
                                            topP: topP,
                                            systemPromptOverride: customDirective
                                        )
                                    }
                                } label: {
                                    HStack {
                                        Text(suggestion)
                                            .font(.system(size: 13, weight: .light))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.cyberGreen)
                                            .opacity(0.6)
                                    }
                                    .padding(.vertical, 12)
                                    .background(Color.clear)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.05))
                                            .frame(height: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func sourcesView(sources: [ChatSource]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SOURCES")
                .metroLabelStyle()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        let hostname = URL(string: source.url)?.host ?? "source"
                        
                        Link(destination: URL(string: source.url) ?? URL(string: "https://mattyhagen.xyz")!) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 14, height: 14)
                                        .background(Color.cyberBlue)
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.3))
                                }
                                
                                Text(source.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Text(hostname)
                                    .font(.system(size: 9, weight: .light))
                                    .foregroundColor(Color.white.opacity(0.35))
                            }
                            .padding(12)
                            .frame(width: 140, height: 86, alignment: .topLeading)
                            .background(Color.cyberGlassBg)
                            .border(Color.white.opacity(0.06), width: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // --- Layout Sections ---
    
    private func emptyChannelView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INTELLIGENCE")
                .font(.system(size: 40, weight: .light))
                .tracking(-1)
                .foregroundColor(.white)
            
            Text("BITCOIN · CRYPTO · NOC OPERATIONS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(Color.white.opacity(0.35))
                .padding(.bottom, 24)
            
            VStack(spacing: 0) {
                ForEach([
                    "What's the latest on BlackRock's Bitcoin ETF?",
                    "Summarize recent hash rate trends",
                    "How does Fed policy impact Bitcoin price?"
                ], id: \.self) { prompt in
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            typedMessage = prompt
                        }
                    } label: {
                        HStack {
                            Text(prompt)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.cyberGreen)
                                .opacity(0.6)
                        }
                        .padding(.vertical, 14)
                        .background(Color.clear)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 40)
    }
    
    private func noConversationView() -> some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("INTELLIGENCE")
                    .font(.system(size: 56, weight: .light))
                    .tracking(-2)
                    .foregroundColor(.white)
                
                Text("NO SESSION ACTIVE")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.cyberBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            
            Text("Create a new thread to establish secure database indexing backplanes.")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                HapticManager.shared.impact(style: .medium)
                Task {
                    if let newId = await client.createConversation() {
                        selectConversation(newId)
                    }
                }
            } label: {
                Text("ESTABLISH NEW THREAD")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyberBlue)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 120)
        }
        .padding(.top, 40)
    }
    
    private func inputBarView(conversationId: Int) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            // Model Selector strip (Sharp horizontal tags)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Text("MODEL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.trailing, 4)
                    
                    ForEach(client.availableModels, id: \.self) { model in
                        Button {
                            HapticManager.shared.impact(style: .light)
                            selectedModel = model
                        } label: {
                            Text(displayName(for: model))
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(selectedModel == model ? .black : Color.white.opacity(0.6))
                                .background(selectedModel == model ? Color.cyberGreen : Color.clear)
                                .border(selectedModel == model ? Color.clear : Color.white.opacity(0.15), width: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(Color.cyberTerminalBg)
            
            // Message input field and flat send button
            HStack(spacing: 16) {
                TextField(client.isStreamingChat ? "Awaiting response..." : "Ask anything...", text: $typedMessage)
                    .disabled(client.isStreamingChat)
                    .focused($isFieldFocused)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(isFieldFocused ? Color.cyberBlue : Color.white.opacity(0.15))
                            .frame(height: 2)
                    }
                
                Button {
                    let content = typedMessage
                    typedMessage = ""
                    HapticManager.shared.impact(style: .medium)
                    Task {
                        await client.sendMessage(
                            conversationId: conversationId,
                            content: content,
                            model: selectedModel,
                            temperature: temperature,
                            topP: topP,
                            systemPromptOverride: customDirective
                        )
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(typedMessage.trimmingCharacters(in: .whitespaces).isEmpty || client.isStreamingChat ? Color.white.opacity(0.15) : Color.cyberGreen)
                }
                .disabled(typedMessage.trimmingCharacters(in: .whitespaces).isEmpty || client.isStreamingChat)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(Color.cyberTerminalBg)
        }
    }
    
    private func displayName(for model: String) -> String {
        if model.contains("phi") {
            return "PHI-3"
        } else if model.contains("qwen") {
            return "QWEN-3"
        }
        return model.uppercased()
    }
    
    private func historySheetView() -> some View {
        NavigationStack {
            ZStack {
                Color.cyberTerminalBg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Button {
                        showHistorySheet = false
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            if let newId = await client.createConversation() {
                                selectConversation(newId)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("ESTABLISH NEW THREAD")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyberGreen)
                    }
                    .padding(20)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(client.conversations) { conv in
                                let isActive = activeConversationId == conv.id
                                
                                HStack {
                                    Button {
                                        HapticManager.shared.impact(style: .light)
                                        selectConversation(conv.id)
                                        showHistorySheet = false
                                    } label: {
                                        Text(conv.title.uppercased())
                                            .font(.system(size: 13, weight: isActive ? .bold : .light))
                                            .foregroundColor(isActive ? Color.cyberGreen : .white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Button {
                                        HapticManager.shared.notification(type: .warning)
                                        Task {
                                            await client.deleteConversation(id: conv.id)
                                            if activeConversationId == conv.id {
                                                activeConversationId = nil
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(.cyberRed.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(isActive ? Color.white.opacity(0.03) : Color.clear)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("SESSION ARCHIVE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("DISMISS") {
                        HapticManager.shared.impact(style: .light)
                        showHistorySheet = false
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                }
            }
            .toolbarBackground(Color.cyberTerminalBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func tuningSheetView() -> some View {
        NavigationStack {
            ZStack {
                Color.cyberTerminalBg.ignoresSafeArea()
                
                Form {
                    Section("ACTIVE ENGINE") {
                        Picker("COMPILER", selection: $selectedModel) {
                            ForEach(client.availableModels, id: \.self) { m in
                                Text(m.uppercased()).tag(m)
                            }
                        }
                        .tint(.cyberGreen)
                        .listRowBackground(Color.white.opacity(0.03))
                    }
                    
                    Section("HYPERPARAMETERS") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("TEMPERATURE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.1f", temperature))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.cyberGreen)
                            }
                            Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                                .tint(.cyberGreen)
                        }
                        .listRowBackground(Color.white.opacity(0.03))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("NUCLEUS LIMIT (TOP P)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.2f", topP))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.cyberGreen)
                            }
                            Slider(value: $topP, in: 0.0...1.0, step: 0.05)
                                .tint(.cyberGreen)
                        }
                        .listRowBackground(Color.white.opacity(0.03))
                    }
                    
                    Section("PERSONA / SYSTEM ALIGNMENT") {
                        TextEditor(text: $customDirective)
                            .foregroundColor(.cyberGreen)
                            .frame(height: 90)
                            .listRowBackground(Color.white.opacity(0.03))
                    }
                    
                    Section {
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            selectedModel = client.availableModels.first ?? "qwen3:8b"
                            temperature = 0.7
                            topP = 0.9
                            customDirective = ""
                        } label: {
                            Text("RESTORE BACKPLANE DEFAULTS")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.cyberRed)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowBackground(Color.white.opacity(0.03))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("ALIGNMENT LOGIC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("APPLY") {
                        HapticManager.shared.impact(style: .medium)
                        showTuningSheet = false
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyberGreen)
                }
            }
            .toolbarBackground(Color.cyberTerminalBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func selectConversation(_ id: Int) {
        activeConversationId = id
        Task {
            await client.fetchMessages(conversationId: id)
        }
    }
}

// MARK: - Thoughts Console Expander View
struct ThoughtsConsoleView: View {
    let thoughts: String
    let isStreaming: Bool
    
    @State private var isCollapsed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                HapticManager.shared.impact(style: .light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("COGNITIVE PATHWAY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                    if isStreaming {
                        Text("(COMPILING...)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.cyberYellow)
                    }
                    Spacer()
                }
                .foregroundColor(Color.cyberGreen.opacity(0.8))
            }
            .buttonStyle(.plain)
            
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 2) {
                        Text(thoughts.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 11, weight: .light, design: .monospaced))
                            .foregroundColor(Color.cyberGreen.opacity(0.85))
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                        
                        if isStreaming {
                            BlinkingCursor()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.black.opacity(0.2))
                .border(Color.cyberGreen.opacity(0.25), width: 1)
            }
        }
    }
}

struct BlinkingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Text("█")
            .font(.system(size: 11))
            .foregroundColor(.cyberGreen)
            .opacity(isVisible ? 0.8 : 0.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Waveform Avatars
struct WaveformAvatar: View {
    let isUser: Bool
    let isStreaming: Bool
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(isUser ? Color.cyberBlue : Color.cyberGreen)
                    .frame(width: 2, height: barHeight(for: index))
            }
        }
        .frame(width: 18, height: 18)
        .onAppear {
            if isStreaming {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    scale = 1.8
                }
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 12, 16, 8]
        return heights[index] * (isStreaming ? scale : 0.7)
    }
}

// MARK: - Typing Indicator Animation View
struct TypingIndicatorView: View {
    @State private var dotOffset1: CGFloat = 0
    @State private var dotOffset2: CGFloat = 0
    @State private var dotOffset3: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.cyberGreen)
                .frame(width: 4, height: 12)
                .offset(y: dotOffset1)
            Rectangle()
                .fill(Color.cyberGreen)
                .frame(width: 4, height: 12)
                .offset(y: dotOffset2)
            Rectangle()
                .fill(Color.cyberGreen)
                .frame(width: 4, height: 12)
                .offset(y: dotOffset3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        let duration: Double = 0.45
        let delay: Double = 0.15
        
        withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            dotOffset1 = -4
        }
        
        withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
            dotOffset2 = -4
        }
        
        withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay * 2)) {
            dotOffset3 = -4
        }
    }
}
