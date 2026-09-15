import Foundation
import CoreGraphics

// --- 1. 基础模型 ---
struct Category: Identifiable, Codable, Equatable {
    var id = UUID()
    let title: String
    let iconPath: String
    let folderName: String
    var itemCount: Int = 0
    enum CodingKeys: String, CodingKey { case title, iconPath, folderName }
}

struct LearningItem: Identifiable, Codable {
    var id = UUID()
    let name: String
    let chineseName: String
    var imageUrl: String
    var stableID: String { "\(name)|\(chineseName)|\(imageUrl)" }
}

struct BodyPart: Identifiable {
    let id = UUID()
    let name: String; let chineseName: String; let x: CGFloat; let y: CGFloat
}

struct DialogueLine: Identifiable, Codable {
    var id = UUID(); let textEN: String; let textCN: String
    enum CodingKeys: String, CodingKey { case textEN, textCN }
}

struct ConversationLesson: Identifiable, Codable, Hashable {
    var id: String { folderName }; let title: String; let folderName: String; let backgroundImage: String; let script: [DialogueLine]
    func hash(into hasher: inout Hasher) { hasher.combine(folderName) }
    static func == (lhs: ConversationLesson, rhs: ConversationLesson) -> Bool { lhs.folderName == rhs.folderName }
}

// --- 2. 逻辑游戏模型 ---
struct LogicItem: Identifiable, Codable {
    var id = UUID()
    let image: String
    let isAnswer: Bool
    enum CodingKeys: String, CodingKey { case image, isAnswer }
}

struct LogicLevel: Identifiable, Codable {
    let id: String; let prompt: String; let items: [LogicItem]
}

struct SequenceStep: Codable, Identifiable, Hashable {
    var id = UUID(); let image: String; let text: String
    enum CodingKeys: String, CodingKey { case image, text }
}

struct SequenceLevel: Identifiable, Codable {
    let id: String; let title: String; let success_video: String?; let steps: [SequenceStep]
}

struct CauseEffectOption: Codable, Identifiable, Hashable {
    var id = UUID(); let image: String; let text: String; let isAnswer: Bool
    enum CodingKeys: String, CodingKey { case image, text, isAnswer }
}

struct CauseEffectLevel: Identifiable, Codable {
    let id: String; let title: String; let prompt: String; let question_image: String; let result_image: String?; let options: [CauseEffectOption]
}

struct MatrixOption: Codable, Identifiable, Hashable {
    let id: String; let image: String; let isAnswer: Bool
}

struct MatrixLevel: Identifiable, Codable {
    let id: String; let difficulty: String; let prompt: String; let layout: String; let matrix_items: [String]; let options: [MatrixOption]
}

struct RavenLevel: Identifiable, Codable {
    let id: String; let image: String; let correct_answer: Int; let option_count: Int
}

struct bBodyPart: Identifiable {
    let id = UUID()
    let name: String
    let chineseName: String
    let x: CGFloat
    let y: CGFloat
    let isLeft: Bool
}

// --- 3. Ogden 单词模型 (修复解析问题) ---
struct OgdenWord: Identifiable, Codable, Hashable {
    var id = UUID() // 自动生成，不从 JSON 读取
    let w: String
    let zh: String
    let ex: String
    let exz: String
    
    // 关键：显式指定 CodingKeys，排除 id，这样 JSON 里没有 id 也能解析成功
    enum CodingKeys: String, CodingKey {
        case w, zh, ex, exz
    }
}

// --- 4. 静态数据 ---
nonisolated let GlobalMarioParts = [
    bBodyPart(name: "head", chineseName: "头部", x: 0.418, y: 0.104, isLeft: true),
    bBodyPart(name: "hair", chineseName: "头发", x: 0.531, y: 0.106, isLeft: false),
    bBodyPart(name: "eyes", chineseName: "眼睛", x: 0.433, y: 0.145, isLeft: true),
    bBodyPart(name: "eyebrow", chineseName: "眉毛", x: 0.494, y: 0.133, isLeft: false),
    bBodyPart(name: "nose", chineseName: "鼻子", x: 0.461, y: 0.156, isLeft: true),
    bBodyPart(name: "ear", chineseName: "耳朵", x: 0.531, y: 0.151, isLeft: false),
    bBodyPart(name: "face", chineseName: "脸", x: 0.434, y: 0.170, isLeft: true),
    bBodyPart(name: "mouth", chineseName: "嘴巴", x: 0.479, y: 0.178, isLeft: false),
    bBodyPart(name: "chin", chineseName: "下巴", x: 0.470, y: 0.193, isLeft: true),
    bBodyPart(name: "throat", chineseName: "喉咙", x: 0.484, y: 0.205, isLeft: false),
    bBodyPart(name: "shoulder", chineseName: "肩膀", x: 0.367, y: 0.236, isLeft: true),
    bBodyPart(name: "neck", chineseName: "脖子", x: 0.440, y: 0.221, isLeft: false),
    bBodyPart(name: "arm", chineseName: "手臂", x: 0.340, y: 0.348, isLeft: true),
    bBodyPart(name: "hand", chineseName: "手", x: 0.558, y: 0.479, isLeft: false),
    bBodyPart(name: "finger", chineseName: "手指", x: 0.300, y: 0.545, isLeft: true),
    bBodyPart(name: "leg", chineseName: "大腿", x: 0.586, y: 0.614, isLeft: false),
    bBodyPart(name: "knee", chineseName: "膝盖", x: 0.587, y: 0.688, isLeft: true),
    bBodyPart(name: "foot", chineseName: "脚", x: 0.622, y: 0.915, isLeft: false),
    bBodyPart(name: "toe", chineseName: "脚趾", x: 0.291, y: 0.911, isLeft: true)
]
