import AVFoundation
import SwiftUI
import Combine

@MainActor
class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {

    static let shared = SpeechManager()

    @Published var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    var onAudioFinished: (() -> Void)?

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioCache")

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }

        return dir
    }()

    private override init() {
        super.init()
        self.synthesizer.delegate = self
        setupSession()

        // 打印当前设备所有可用的系统语音
        //printAvailableVoices()
    }

    private func setupSession() {
        let session = AVAudioSession.sharedInstance()

        try? session.setCategory(
            .playback,
            mode: .default,
            options: .mixWithOthers
        )

        try? session.setActive(
            true,
            options: .notifyOthersOnDeactivation
        )
    }

    // MARK: - Debug: 打印所有系统语音

    //private func printAvailableVoices() {
    //    let voices = AVSpeechSynthesisVoice.speechVoices()
//
    //    print("")
    //    print("========== AVSpeechSynthesisVoice 可用语音 ==========")
    //    print("总数量: \(voices.count)")
    //    print("")
//
    //    for voice in voices.sorted(by: {
    //        if $0.language == $1.language {
    //            return $0.name < $1.name
    //        }
    //        return $0.language < $1.language
    //    }) {
    //        let quality: String
//
    //        switch voice.quality {
    //        case .default:
    //            quality = "default"
    //        case .enhanced:
    //            quality = "enhanced"
    //        case .premium:
    //            quality = "premium"
    //        @unknown default:
    //            quality = "unknown"
    //        }
//
    //        print("""
    //        name       = \(voice.name)
    //        identifier = \(voice.identifier)
    //        language   = \(voice.language)
    //        quality    = \(quality) (\(voice.quality.rawValue))
    //        ------------------------------
    //        """)
    //    }
//
    //    print("======================================================")
    //    print("")
    //}

    // MARK: - Speech

    func speak(english: String, chinese: String) {
        stop()
        isSpeaking = true

        if !english.isEmpty {
            play(text: english, lang: "en-US") { [weak self] in

                if !chinese.isEmpty {
                    self?.speakChineseWithPauses(chinese: chinese) {
                        self?.isSpeaking = false
                    }
                } else {
                    self?.isSpeaking = false
                }
            }

        } else if !chinese.isEmpty {
            speakChineseWithPauses(chinese: chinese) { [weak self] in
                self?.isSpeaking = false
            }

        } else {
            isSpeaking = false
        }
    }

    func speakChineseWithPauses(
        chinese: String,
        completion: @escaping () -> Void
    ) {
        // 将中文文本按标点符号分割
        let pattern = "([。，！？；：、])"
        let regex = try? NSRegularExpression(pattern: pattern)

        let matches = regex?.matches(
            in: chinese,
            range: NSRange(
                location: 0,
                length: chinese.utf16.count
            )
        ) ?? []

        if matches.isEmpty {
            // 没有标点符号，直接朗读
            play(
                text: chinese,
                lang: "zh-CN"
            ) {
                completion()
            }

            return
        }

        // 有标点符号，分段朗读
        var parts: [String] = []
        var currentIndex = chinese.startIndex

        for match in matches {
            let matchRange = Range(match.range, in: chinese)!
            let part = String(
                chinese[currentIndex..<matchRange.lowerBound]
            )
            let punctuation = String(chinese[matchRange])

            if !part.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                parts.append(part)
            }

            // 添加标点符号作为单独的部分
            parts.append(punctuation)

            currentIndex = matchRange.upperBound
        }

        // 添加最后一部分
        let lastPart = String(chinese[currentIndex...])

        if !lastPart.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            parts.append(lastPart)
        }

        // 逐段朗读
        speakParts(
            parts: parts,
            index: 0,
            completion: completion
        )
    }

    private func speakParts(
        parts: [String],
        index: Int,
        completion: @escaping () -> Void
    ) {
        if index >= parts.count {
            completion()
            return
        }

        let part = parts[index]

        guard !part.isEmpty else {
            speakParts(
                parts: parts,
                index: index + 1,
                completion: completion
            )
            return
        }

        // 如果是标点符号，使用较短的停顿
        let isPunctuation =
            part.rangeOfCharacter(
                from: CharacterSet.punctuationCharacters
            ) != nil

        play(
            text: part,
            lang: "zh-CN"
        ) { [weak self] in

            let delay = isPunctuation ? 0.3 : 0.5

            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay
            ) {
                self?.speakParts(
                    parts: parts,
                    index: index + 1,
                    completion: completion
                )
            }
        }
    }

    func speakText(_ text: String, language: String) {
        stop()
        isSpeaking = true

        play(
            text: text,
            lang: language
        ) { [weak self] in
            self?.isSpeaking = false
        }
    }

    func speakAIText(_ text: String) {
        speakSynthesizedText(
            text: text,
            language: "zh-CN",
            voiceIdentifier: SecureSettingsStore.shared.chineseVoiceIdentifier
        )
    }

    /// 基础单词朗读：英文 + 中文，全部使用 iOS 系统本地语音（用户在设置中选择）
    func speakVocabularyWord(english: String, chinese: String) {
        stop()
        isSpeaking = true

        let rate = Float(SecureSettingsStore.shared.aiVoiceRate)
        let pitch = Float(SecureSettingsStore.shared.aiVoicePitch)

        if !english.isEmpty {
            speakSynthesized(
                text: english,
                language: "en-US",
                voiceIdentifier: SecureSettingsStore.shared.englishVoiceIdentifier,
                rate: rate,
                pitch: pitch
            ) { [weak self] in
                if !chinese.isEmpty {
                    self?.speakSynthesized(
                        text: chinese,
                        language: "zh-CN",
                        voiceIdentifier: SecureSettingsStore.shared.chineseVoiceIdentifier,
                        rate: rate,
                        pitch: pitch
                    ) { [weak self] in
                        self?.isSpeaking = false
                    }
                } else {
                    self?.isSpeaking = false
                }
            }

        } else if !chinese.isEmpty {
            speakSynthesized(
                text: chinese,
                language: "zh-CN",
                voiceIdentifier: SecureSettingsStore.shared.chineseVoiceIdentifier,
                rate: rate,
                pitch: pitch
            ) { [weak self] in
                self?.isSpeaking = false
            }

        } else {
            isSpeaking = false
        }
    }

    /// 试听中文语音
    func previewChineseText() {
        speakSynthesizedText(
            text: "你好呀！我是你的英语小老师，我们一起去学习英语吧。",
            language: "zh-CN",
            voiceIdentifier: SecureSettingsStore.shared.chineseVoiceIdentifier
        )
    }

    /// 试听英文语音
    func previewEnglishText() {
        speakSynthesizedText(
            text: "Hello! I am your English teacher. Let's learn English together!",
            language: "en-US",
            voiceIdentifier: SecureSettingsStore.shared.englishVoiceIdentifier
        )
    }

    private func speakSynthesizedText(
        text: String,
        language: String,
        voiceIdentifier: String
    ) {
        stop()
        isSpeaking = true

        speakSynthesized(
            text: text,
            language: language,
            voiceIdentifier: voiceIdentifier,
            rate: Float(SecureSettingsStore.shared.aiVoiceRate),
            pitch: Float(SecureSettingsStore.shared.aiVoicePitch)
        ) { [weak self] in
            self?.isSpeaking = false
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        onAudioFinished = nil
        isSpeaking = false
    }

    func playLocalAudio(url: URL) {
        stop()
        isSpeaking = true
        setupSession()

        playFile(url: url) { [weak self] in
            self?.isSpeaking = false
        }
    }

    // MARK: - Local / Cached Audio

    private func play(
        text: String,
        lang: String,
        completion: @escaping () -> Void
    ) {
        setupSession()

        let name = generateExactFilename(for: text)
        let url = cacheDir.appendingPathComponent("\(name).mp3")

        if FileManager.default.fileExists(atPath: url.path) {
            playFile(
                url: url,
                completion: completion
            )

        } else if let bundled = ResourceLocator.bundleURL(
            relativePath: "audio/\(name).mp3"
        ) {
            playFile(
                url: bundled,
                completion: completion
            )

        } else {
            download(
                name: name,
                url: url,
                text: text,
                lang: lang,
                completion: completion
            )
        }
    }

    private func generateExactFilename(for text: String) -> String {
        let pattern =
            "[\\\\/\\*|#.,!?;:。，！？；：、~`'\"“”‘’()（）\\[\\]<>{}]"

        let regex = try? NSRegularExpression(
            pattern: pattern
        )

        return regex?.stringByReplacingMatches(
            in: text,
            range: NSRange(
                location: 0,
                length: text.utf16.count
            ),
            withTemplate: ""
        ).trimmingCharacters(
            in: .whitespaces
        ) ?? text
    }

    private func download(
        name: String,
        url: URL,
        text: String,
        lang: String,
        completion: @escaping () -> Void
    ) {
        // REMOTE DISABLED
        fallback(
            text,
            lang,
            completion
        )
    }

    private func playFile(
        url: URL,
        completion: @escaping () -> Void
    ) {
        setupSession()

        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        onAudioFinished = completion
        audioPlayer?.play()
    }

    // MARK: - System TTS

    private func fallback(
        _ text: String,
        _ lang: String,
        _ completion: @escaping () -> Void
    ) {
        // 暂时不硬编码 identifier。
        // 先通过 Xcode 控制台确认 Samantha / Yue Premium 的实际 identifier。
        let voiceIdentifier = ""

        let rate: Float = 0.35
        let pitch: Float = 1.0

        speakSynthesized(
            text: text,
            language: lang,
            voiceIdentifier: voiceIdentifier,
            rate: rate,
            pitch: pitch,
            completion: completion
        )
    }

    private func speakSynthesized(
        text: String,
        language: String,
        voiceIdentifier: String,
        rate: Float,
        pitch: Float,
        completion: @escaping () -> Void
    ) {
        setupSession()

        let utt = AVSpeechUtterance(string: text)

        utt.rate = rate
        utt.pitchMultiplier = pitch

        if !voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(
                identifier: voiceIdentifier
           ) {

            utt.voice = voice

            print(
                "[Speech] 使用指定语音: \(voice.name) | " +
                "\(voice.identifier) | " +
                "\(voice.language) | " +
                "quality=\(voice.quality.rawValue)"
            )

        } else if let voice = preferredVoice(for: language) {

            utt.voice = voice

            print(
                "[Speech] 使用默认匹配语音: \(voice.name) | " +
                "\(voice.identifier) | " +
                "\(voice.language) | " +
                "quality=\(voice.quality.rawValue)"
            )
        }

        synthesizer.speak(utt)

        DispatchQueue.main.asyncAfter(
            deadline: .now() +
                Double(text.count) * 0.15 +
                0.5
        ) {
            completion()
        }
    }

    // MARK: - Voice Selection

    private func preferredVoice(
        for language: String
    ) -> AVSpeechSynthesisVoice? {

        // 英文：优先 Samantha
        if language.hasPrefix("en") {

            let voices = AVSpeechSynthesisVoice
                .speechVoices()
                .filter {
                    $0.language.hasPrefix("en")
                }

            if let voice = voices.first(where: {
                $0.name.localizedCaseInsensitiveContains("Samantha")
            }) {
                return voice
            }

            // 找不到 Samantha，使用质量最高的英文语音
            return voices
                .sorted {
                    $0.quality.rawValue > $1.quality.rawValue
                }
                .first
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        // 中文：
        // 先寻找名字包含 Yue 且质量为 Premium 的语音
        let voices = AVSpeechSynthesisVoice
            .speechVoices()
            .filter {
                $0.language.hasPrefix("zh") ||
                $0.language.hasPrefix("yue")
            }

        if let voice = voices.first(where: {
            $0.name.localizedCaseInsensitiveContains("Yue") &&
            $0.quality == .premium
        }) {
            return voice
        }

        // 如果没有 Premium Yue，则寻找 Yue
        if let voice = voices.first(where: {
            $0.name.localizedCaseInsensitiveContains("Yue")
        }) {
            return voice
        }

        // 最终 fallback
        return voices
            .sorted {
                $0.quality.rawValue > $1.quality.rawValue
            }
            .first
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }

    // MARK: - Audio Delegate

    nonisolated
    func audioPlayerDidFinishPlaying(
        _ p: AVAudioPlayer,
        successfully f: Bool
    ) {
        Task { @MainActor in
            SpeechManager.shared.onAudioFinished?()
            SpeechManager.shared.onAudioFinished = nil
        }
    }
}
