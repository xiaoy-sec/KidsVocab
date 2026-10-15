import AVFoundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var historyMgr = HistoryManager.shared

    // 弹窗状态控制
    @State private var showingDeepCleanAlert = false
    @State private var showingResetHistoryAlert = false
    @State private var deepSeekAPIKey = ""
    @State private var deepSeekModel = "deepseek-chat"
    @State private var chineseVoiceIdentifier = ""
    @State private var englishVoiceIdentifier = ""
    @State private var aiVoiceRate = 0.40
    @State private var aiVoicePitch = 1.05
    @State private var vocabularySpeechMode = "normal"
    private let chineseVoices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("yue") }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    private let englishVoices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("en") }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 1. 学习进度管理
                //Section(header: Text("学习进度管理"), footer: //Text("重置进度将删除所有打卡记录和已学单词，一切从头开始。此操作不可撤销。")) {
                //    HStack {
                //        Text("当前已学单词数")
                //        Spacer()
                //        Text("\(historyMgr.getAllLearnedWordNames().count)")
                //            .foregroundColor(.secondary)
                //    }
//
                //    Button(action: {
                //        showingResetHistoryAlert = true
                //    }) {
                //        Label("重置学习进度", systemImage: "arrow.counterclockwise")
                //            .foregroundColor(.red)
                //    }
                //    .alert("确定要重置吗？", isPresented: $showingResetHistoryAlert) {
                //        Button("取消", role: .cancel) { }
                //        Button("确定重置", role: .destructive) {
                //            historyMgr.resetHistory()
                //        }
                //    } message: {
                //        Text("所有的金色打卡记录都会消失，孩子需要重新开始闯关。")
                //    }
                //}

                Section(header: Text("基础单词朗读"), footer: Text("点击「基础单词」中的单词时，按所选模式进行朗读。")) {
                    Picker("朗读模式", selection: $vocabularySpeechMode) {
                        Text("正常模式（英文 + 中文）").tag("normal")
                        Text("英文模式（只读英文）").tag("englishOnly")
                        Text("中文模式（只读中文）").tag("chineseOnly")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vocabularySpeechMode) { _, newValue in
                        SecureSettingsStore.shared.vocabularySpeechMode = newValue
                    }
                }

                Section(header: Text("AI 对话"), footer: Text("DeepSeek API Key 会保存在本机 Keychain 中。")) {
                    SecureField("DeepSeek API Key", text: $deepSeekAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: deepSeekAPIKey) { _, newValue in
                            SecureSettingsStore.shared.deepSeekAPIKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    Picker("模型", selection: $deepSeekModel) {
                        Text("deepseek-chat").tag("deepseek-chat")
                        Text("deepseek-reasoner").tag("deepseek-reasoner")
                    }
                    .onChange(of: deepSeekModel) { _, newValue in
                        SecureSettingsStore.shared.deepSeekModel = newValue
                    }
                }

                Section(header: Text("本地语音"), footer: Text("AI 对话和基础单词均使用设备已安装的系统语音。")) {
                    Picker("中文语音", selection: $chineseVoiceIdentifier) {
                        Text("自动选择").tag("")
                        ForEach(chineseVoices, id: \.identifier) { voice in
                            Text(voiceDisplayName(voice)).tag(voice.identifier)
                        }
                    }
                    .onChange(of: chineseVoiceIdentifier) { _, newValue in
                        SecureSettingsStore.shared.chineseVoiceIdentifier = newValue
                    }

                    Button(action: { SpeechManager.shared.previewChineseText() }) {
                        Label("试听中文语音", systemImage: "speaker.wave.2.fill")
                    }

                    Picker("英文语音", selection: $englishVoiceIdentifier) {
                        Text("自动选择").tag("")
                        ForEach(englishVoices, id: \.identifier) { voice in
                            Text(voiceDisplayName(voice)).tag(voice.identifier)
                        }
                    }
                    .onChange(of: englishVoiceIdentifier) { _, newValue in
                        SecureSettingsStore.shared.englishVoiceIdentifier = newValue
                    }

                    Button(action: { SpeechManager.shared.previewEnglishText() }) {
                        Label("试听英文语音", systemImage: "speaker.wave.2.fill")
                    }

                    VStack(alignment: .leading) {
                        Text("语速 \(String(format: "%.2f", aiVoiceRate))")
                        Slider(value: $aiVoiceRate, in: 0.30...0.55, step: 0.01)
                            .onChange(of: aiVoiceRate) { _, newValue in
                                SecureSettingsStore.shared.aiVoiceRate = newValue
                            }
                    }

                    VStack(alignment: .leading) {
                        Text("音高 \(String(format: "%.2f", aiVoicePitch))")
                        Slider(value: $aiVoicePitch, in: 0.85...1.25, step: 0.01)
                            .onChange(of: aiVoicePitch) { _, newValue in
                                SecureSettingsStore.shared.aiVoicePitch = newValue
                            }
                    }

                }

                // MARK: - 2. 数据缓存管理
                Section(header: Text("存储空间"), footer: Text("深度清理只会删除缓存和临时文件，学习进度与用户文件会保留。")) {
                    Button(role: .destructive, action: {
                        deepCleanPreservingHistory()
                        showingDeepCleanAlert = true
                    }) {
                        Label("深度清理(保留进度)", systemImage: "trash.slash")
                    }
                    .alert("深度清理完成", isPresented: $showingDeepCleanAlert) {
                        Button("好的", role: .cancel) { }
                    } message: {
                        Text("已删除缓存与临时文件，学习进度与用户文件已保留。")
                    }
                }

                // MARK: - 3. 关于
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text("1.0.0 (Beta)")
                            .foregroundColor(.secondary)
                    }
                    Text("Made with ❤️ for Kids")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
        }
        .onAppear {
            deepSeekAPIKey = SecureSettingsStore.shared.deepSeekAPIKey
            deepSeekModel = SecureSettingsStore.shared.deepSeekModel
            chineseVoiceIdentifier = SecureSettingsStore.shared.chineseVoiceIdentifier
            englishVoiceIdentifier = SecureSettingsStore.shared.englishVoiceIdentifier
            aiVoiceRate = SecureSettingsStore.shared.aiVoiceRate
            aiVoicePitch = SecureSettingsStore.shared.aiVoicePitch
            vocabularySpeechMode = SecureSettingsStore.shared.vocabularySpeechMode
        }
    }

    // MARK: - 逻辑函数
    private func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        "\(voice.name) - \(voice.language)"
    }

    private func deepCleanPreservingHistory() {
        let fileManager = FileManager.default

        // 1. 清理 Caches
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }

        // 2. 清理 tmp
        let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        if let files = try? fileManager.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }

        // 3. 清理 Documents，但保留学习进度
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        _ = documentsDirectory

        // 4. 重置内存数据
        CategoryManager.shared.categories = []

        print("深度清理完成(已保留学习进度)")
    }
}
