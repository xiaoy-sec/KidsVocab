import AVFoundation
import Combine
import Foundation
import Speech

struct AIChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case child
        case ai
    }

    enum Status: Codable, Equatable {
        case sending
        case done
        case failed(String)
    }

    var id = UUID()
    let role: Role
    var transcript: String
    var duration: TimeInterval
    var status: Status
    var audioURL: URL? = nil
    var createdAt = Date()
}

@MainActor
final class AIChatManager: NSObject, ObservableObject {
    @Published var messages: [AIChatMessage] = [
        AIChatMessage(role: .ai, transcript: "你好。按住下面的话筒，问我英语问题吧。", duration: 3, status: .done)
    ]
    @Published var conversations: [AIChatConversation] = []
    @Published var selectedConversationID: UUID?
    @Published var isRecording = false
    @Published var isSending = false
    @Published var liveTranscript = ""
    @Published var statusText = "按住说话"

    private let historyStore = AIChatHistoryStore.shared
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingStartedAt: Date?
    private var recordingFile: AVAudioFile?
    private var currentRecordingURL: URL?
    private let deepSeekService = DeepSeekService()

    override init() {
        super.init()
        loadHistory()
    }

    func playWelcomeIfNeeded() {
        guard messages.count == 1, case .ai = messages[0].role else { return }
        let welcome = messages[0]
        SpeechManager.shared.speakAIText(welcome.transcript)
    }

    func startNewConversation() {
        SpeechManager.shared.stop()
        let conversation = makeEmptyConversation()
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        messages = conversation.messages
        persistCurrentConversation()
    }

    func selectConversation(_ conversation: AIChatConversation) {
        SpeechManager.shared.stop()
        selectedConversationID = conversation.id
        messages = conversation.messages
        liveTranscript = ""
        statusText = "按住说话"
    }

    func deleteConversation(_ conversation: AIChatConversation) {
        deleteAudioFiles(for: conversation)
        conversations.removeAll { $0.id == conversation.id }
        if selectedConversationID == conversation.id {
            if let next = conversations.first {
                selectedConversationID = next.id
                messages = next.messages
            } else {
                let newConversation = makeEmptyConversation()
                conversations = [newConversation]
                selectedConversationID = newConversation.id
                messages = newConversation.messages
            }
        }
        saveHistory()
    }

    func startRecording() async {
        guard !isRecording, !isSending else { return }
        SpeechManager.shared.stop()

        let allowed = await requestSpeechAndMicPermission()
        guard allowed else {
            statusText = "需要麦克风和语音识别权限"
            return
        }

        do {
            try beginSpeechRecognition()
            liveTranscript = ""
            recordingStartedAt = Date()
            isRecording = true
            statusText = "松开发送"
        } catch {
            statusText = "录音启动失败"
        }
    }

    func stopRecordingAndSend() {
        guard isRecording else { return }
        let duration = Date().timeIntervalSince(recordingStartedAt ?? Date())
        let audioURL = currentRecordingURL
        stopRecognition()
        isRecording = false
        statusText = "正在发送..."

        let transcript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            statusText = "没有听清，再说一次"
            return
        }

        let childMessage = AIChatMessage(role: .child, transcript: transcript, duration: max(duration, 1), status: .done, audioURL: audioURL)
        messages.append(childMessage)
        liveTranscript = ""
        persistCurrentConversation()

        Task { await sendToDeepSeek(transcript) }
    }

    func replay(_ message: AIChatMessage) {
        SpeechManager.shared.speakAIText(message.transcript)
    }

    private func sendToDeepSeek(_ transcript: String) async {
        isSending = true
        var aiMessage = AIChatMessage(role: .ai, transcript: "正在想一想...", duration: 2, status: .sending)
        messages.append(aiMessage)
        persistCurrentConversation()

        do {
            let answer = try await deepSeekService.askKidEnglishTeacher(question: transcript)
            aiMessage.transcript = answer
            aiMessage.duration = estimatedDuration(for: answer)
            aiMessage.status = .done
            replaceMessage(aiMessage)
            persistCurrentConversation()
            statusText = "按住说话"
            SpeechManager.shared.speakAIText(answer)
        } catch {
            aiMessage.transcript = error.localizedDescription
            aiMessage.status = .failed(error.localizedDescription)
            replaceMessage(aiMessage)
            persistCurrentConversation()
            statusText = "发送失败"
        }

        isSending = false
    }

    private func replaceMessage(_ message: AIChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = message
    }

    private func loadHistory() {
        conversations = historyStore.loadConversations()
        if let first = conversations.first {
            selectedConversationID = first.id
            messages = first.messages
        } else {
            let conversation = makeEmptyConversation()
            conversations = [conversation]
            selectedConversationID = conversation.id
            messages = conversation.messages
            saveHistory()
        }
    }

    private func persistCurrentConversation() {
        guard let selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == selectedConversationID }) else { return }
        var conversation = conversations[index]
        conversation.messages = messages
        conversation.updatedAt = Date()
        conversation.title = makeTitle(from: messages)
        conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
        self.selectedConversationID = conversation.id
        saveHistory()
    }

    private func saveHistory() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
        historyStore.saveConversations(conversations)
    }

    private func deleteAudioFiles(for conversation: AIChatConversation) {
        for message in conversation.messages {
            guard let audioURL = message.audioURL, audioURL.isFileURL else { continue }
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    private func makeEmptyConversation() -> AIChatConversation {
        let now = Date()
        return AIChatConversation(id: UUID(), title: "新的对话", messages: [welcomeMessage], createdAt: now, updatedAt: now)
    }

    private var welcomeMessage: AIChatMessage {
        AIChatMessage(role: .ai, transcript: "你好，按住下面的话筒，问我英语问题吧。", duration: 3, status: .done)
    }

    private func makeTitle(from messages: [AIChatMessage]) -> String {
        let title = messages.first(where: { $0.role == .child })?.transcript ?? "新的对话"
        return String(title.prefix(18))
    }

    private func requestSpeechAndMicPermission() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micAllowed = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }

        return speechAllowed && micAllowed
    }

    private func beginSpeechRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { throw AIChatError.speechUnavailable }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.liveTranscript = result.bestTranscription.formattedString
                }
                if error != nil {
                    self?.stopRecognition()
                    self?.isRecording = false
                    self?.statusText = "识别中断，请重试"
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        currentRecordingURL = makeRecordingURL()
        if let currentRecordingURL {
            recordingFile = try AVAudioFile(forWriting: currentRecordingURL, settings: format.settings)
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            try? self?.recordingFile?.write(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        recordingFile = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func makeRecordingURL() -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ChatRecordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("\(UUID().uuidString).caf")
    }

    private func estimatedDuration(for text: String) -> TimeInterval {
        max(2, min(12, Double(text.count) * 0.18))
    }
}

enum AIChatError: Error {
    case speechUnavailable
}

