import SwiftUI

struct RootView: View {
    var body: some View {
        AIChatView()
    }
}

struct AIChatView: View {
    @StateObject private var manager = AIChatManager()
    @State private var isPressingVoiceButton = false
    @State private var isSidebarVisible = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        sidebarView
                            .frame(width: min(geometry.size.width * 0.34, 320))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    VStack(spacing: 0) {
                        headerView
                        messageList
                        bottomVoiceBar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(chatBackground.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.22), value: isSidebarVisible)
            }
            .navigationBarHidden(true)
        }
        .onAppear { manager.playWelcomeIfNeeded() }
    }

    private var sidebarView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("对话历史")
                    .font(.headline)
                Spacer()
                Button(action: { manager.startNewConversation() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(accentGreen)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            List(selection: $manager.selectedConversationID) {
                ForEach(manager.conversations) { conversation in
                    Button(action: { manager.selectConversation(conversation) }) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(conversation.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(conversation.updatedAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                    .listRowBackground(conversation.id == manager.selectedConversationID ? accentGreen.opacity(colorScheme == .dark ? 0.22 : 0.12) : Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            manager.deleteConversation(conversation)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 0.5)
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: { isSidebarVisible.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.title3.bold())
                    .foregroundColor(accentGreen)
                    .padding(8)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("英语对话老师")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(manager.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            NavigationLink(destination: MainTabView()) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("学习中心")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(accentGreen))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
        .shadow(color: shadowColor, radius: 8, y: 3)
    }

    private var chatBackground: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground)
    }

    private var accentGreen: Color {
        colorScheme == .dark ? Color(red: 36/255, green: 156/255, blue: 92/255) : Color.green
    }

    private var recordingRed: Color {
        colorScheme == .dark ? Color(red: 224/255, green: 72/255, blue: 72/255) : Color.red
    }

    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(manager.messages) { message in
                        AIChatBubble(message: message) {
                            manager.replay(message)
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .onChange(of: manager.messages) { _, messages in
                guard let last = messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var liveTranscriptBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(manager.liveTranscript.isEmpty ? "正在听..." : manager.liveTranscript)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18).fill(accentGreen.opacity(0.9)))
        }
    }

    private var bottomVoiceBar: some View {
        VStack(spacing: 10) {
            if manager.isSending {
                ProgressView("正在回复...")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                Spacer()

                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isPressingVoiceButton ? recordingRed.opacity(0.18) : accentGreen.opacity(0.14))
                            .frame(width: 98, height: 98)
                            .scaleEffect(isPressingVoiceButton ? 1.12 : 1.0)

                        Circle()
                            .fill(isPressingVoiceButton ? recordingRed : accentGreen)
                            .frame(width: 76, height: 76)
                            .shadow(color: (isPressingVoiceButton ? recordingRed : accentGreen).opacity(0.35), radius: 10, y: 5)

                        Image(systemName: isPressingVoiceButton ? "waveform" : "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(isPressingVoiceButton ? "松开发送" : "按住说话")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPressingVoiceButton else { return }
                            isPressingVoiceButton = true
                            Task { await manager.startRecording() }
                        }
                        .onEnded { _ in
                            isPressingVoiceButton = false
                            manager.stopRecordingAndSend()
                        }
                )
                .opacity(manager.isSending ? 0.45 : 1.0)
                .allowsHitTesting(!manager.isSending)

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
    }
}

struct AIChatBubble: View {
    let message: AIChatMessage
    let onReplay: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var isChild: Bool { message.role == .child }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isChild { Spacer(minLength: 50) }

            if !isChild { avatarView }

            VStack(alignment: isChild ? .trailing : .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    if isChild { Spacer(minLength: 8) }
                    Text(message.transcript)
                        .font(.system(size: 16))
                        .foregroundColor(isChild ? .white : .primary)
                        .multilineTextAlignment(isChild ? .trailing : .leading)
                    Button(action: playMessageAudio) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(isChild ? .white : accentGreen)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isChild ? accentGreen : Color(.secondarySystemBackground))
                )
                .shadow(color: shadowColor, radius: 2, y: 1)
            }

            if !isChild { Spacer(minLength: 50) }
        }
    }

    private func playMessageAudio() {
        SpeechManager.shared.speakAIText(message.transcript)
    }

    private var avatarView: some View {
        ZStack {
            Circle().fill(accentGreen.opacity(colorScheme == .dark ? 0.24 : 0.16))
            Image(systemName: "graduationcap.fill")
                .foregroundColor(accentGreen)
        }
        .frame(width: 34, height: 34)
    }

    private var accentGreen: Color {
        colorScheme == .dark ? Color(red: 36/255, green: 156/255, blue: 92/255) : Color.green
    }

    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05)
    }
}
