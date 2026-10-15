import Foundation
import Security

final class SecureSettingsStore {
    static let shared = SecureSettingsStore()

    private let service = "KidsVocab.DeepSeek"
    private let apiKeyAccount = "apiKey"

    private init() {}

    var deepSeekAPIKey: String {
        get { read(account: apiKeyAccount) ?? "" }
        set { save(newValue, account: apiKeyAccount) }
    }

    var deepSeekModel: String {
        get { UserDefaults.standard.string(forKey: "deepSeekModel") ?? "deepseek-chat" }
        set { UserDefaults.standard.set(newValue, forKey: "deepSeekModel") }
    }

    var chineseVoiceIdentifier: String {
        get {
            UserDefaults.standard.string(forKey: "chineseVoiceIdentifier")
                ?? UserDefaults.standard.string(forKey: "aiChineseVoiceIdentifier") ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: "chineseVoiceIdentifier") }
    }

    var englishVoiceIdentifier: String {
        get { UserDefaults.standard.string(forKey: "englishVoiceIdentifier") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "englishVoiceIdentifier") }
    }

    var aiVoiceRate: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: "aiVoiceRate")
            return saved == 0 ? 0.40 : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: "aiVoiceRate") }
    }

    var aiVoicePitch: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: "aiVoicePitch")
            return saved == 0 ? 1.05 : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: "aiVoicePitch") }
    }

    // MARK: - 基础单词朗读模式

    var vocabularySpeechMode: String {
        get { UserDefaults.standard.string(forKey: "vocabularySpeechMode") ?? "normal" }
        set { UserDefaults.standard.set(newValue, forKey: "vocabularySpeechMode") }
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func save(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if value.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
