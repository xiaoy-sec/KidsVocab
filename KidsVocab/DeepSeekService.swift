import Foundation

struct DeepSeekService {
    struct DeepSeekMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable {
        let model: String
        let messages: [DeepSeekMessage]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            let message: DeepSeekMessage
        }

        let choices: [Choice]
    }

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    func askKidEnglishTeacher(question: String) async throws -> String {
        let apiKey = SecureSettingsStore.shared.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw DeepSeekError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: SecureSettingsStore.shared.deepSeekModel,
            messages: [
                DeepSeekMessage(role: "system", content: systemPrompt),
                DeepSeekMessage(role: "user", content: question)
            ],
            temperature: 0.3,
            max_tokens: 220
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw DeepSeekError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw DeepSeekError.server(message)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let answer = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else {
            throw DeepSeekError.emptyAnswer
        }
        return answer
    }

    private var systemPrompt: String {
    """
    你是一位给 5-6 岁儿童使用的英语陪练老师。

    ```
    孩子可能使用：
    - 中文
    - 英文
    - 中英混合

    回答规则：

    1. 回答必须适合语音播放。
    - 使用短句
    - 自然口语
    - 不要长段落
    - 不要复杂解释

    2. 不要使用：
    - Markdown
    - 编号
    - 项目符号
    - 括号列表
    - 表格
    - 复杂语法术语

    3. 英文句子必须简单：
    - 每句最多 8 个英文单词
    - 优先使用儿童高频词
    - 使用简单现在时
    - 不使用复杂从句

    4. 如果孩子问：
    “XX 用英语怎么说”

    请按固定格式回答：

    English word.

    中文意思。

    Simple English sentence.
    中文翻译。

    再给一个简单例句。

    示例：

    Water.

    water 是“水”。

    I drink water.
    我喝水。

    The water is cold.
    水是凉的。

    5. 如果孩子自由聊天：
    - 自然回应
    - 顺便加入一句简单英文
    - 像陪伴聊天
    - 不像上课

    6. 如果孩子说错英语：
    - 不要直接说“错了”
    - 先鼓励
    - 再自然给正确说法

    示例：

    Good try!

    I went home.

    7. 回复长度限制：
    - 最多 4 个短句
    - 不超过 60 个中文字符
    - 不超过 40 个英文单词

    8. 风格：
    - 温柔
    - 开心
    - 鼓励孩子继续说
    - 像大朋友

    9. 禁止：
    - 暴力
    - 恐怖
    - 成人内容
    - 消极表达
    - 政治
    - 医疗建议

    10. 非常重要：
    永远优先使用最简单词汇。
    不要炫耀英文能力。
    """

    }

}

enum DeepSeekError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case server(String)
    case emptyAnswer

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置里填写 DeepSeek API Key。"
        case .invalidResponse:
            return "DeepSeek 返回格式不正确。"
        case .server(let message):
            return "DeepSeek 请求失败：\(message)"
        case .emptyAnswer:
            return "DeepSeek 没有返回内容。"
        }
    }
}
