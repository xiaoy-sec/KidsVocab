import Foundation
import SwiftUI
import Combine

// MARK: - 数据模型
struct DailyRecord: Codable, Identifiable {
    var id: String { dateString } // 使用日期作为唯一ID
    let dateString: String        // 格式 "2026-02-12"
    let learnedWords: [String]    // 今天学的单词ID
    var isCompleted: Bool         // 是否完成了当天的所有关卡
    
    // 🌟 新增：记录当天学的对话Lesson文件夹名 (设为可选值，防止旧数据崩溃)
    var learnedLesson: String?
}

// MARK: - 历史记录管理器
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var history: [DailyRecord] = []
    
    // 存档文件路径
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("learning_history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    // MARK: - 1. 读写逻辑
    private func loadHistory() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([DailyRecord].self, from: data) {
            self.history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            try? encoded.write(to: fileURL)
        }
    }
    
    // MARK: - 2. 核心功能
    
    /// 获取某天的记录
    func getRecord(for date: Date) -> DailyRecord? {
        let dateStr = formatDate(date)
        return history.first(where: { $0.dateString == dateStr })
    }
    
    /// 🌟 更新：打卡成功，保存记录 (加入 lessonFolder 参数)
    func saveTodayRecord(words: [LearningItem], lessonFolder: String? = nil) {
        let dateStr = formatDate(Date())
        let wordIDs = words.map { $0.name } // 存英文名作为ID
        
        if let index = history.firstIndex(where: { $0.dateString == dateStr }) {
            // 覆盖旧记录，但保留可能已经存过的 learnedLesson
            let finalLesson = lessonFolder ?? history[index].learnedLesson
            history[index] = DailyRecord(dateString: dateStr, learnedWords: wordIDs, isCompleted: true, learnedLesson: finalLesson)
        } else {
            let newRecord = DailyRecord(dateString: dateStr, learnedWords: wordIDs, isCompleted: true, learnedLesson: lessonFolder)
            history.append(newRecord)
        }
        saveHistory()
    }
    
    // MARK: - 3. 智能抽题逻辑
    
    /// 获取所有已经学过的单词 ID 集合
    func getAllLearnedWordNames() -> Set<String> {
        let all = history.flatMap { $0.learnedWords }
        return Set(all)
    }
    
    /// 获取昨天的单词 (用于复习)
    func getReviewWords(allServerItems: [LearningItem]) -> [LearningItem] {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return [] }
        let dateStr = formatDate(yesterday)
        
        if let record = history.first(where: { $0.dateString == dateStr }) {
            return allServerItems.filter { record.learnedWords.contains($0.name) }
        }
        return []
    }
    
    /// 🌟 核心新增：计算下一个应该学的对话 Lesson
    func getNextLessonFolder(availableFolders: [String]) -> String? {
        guard !availableFolders.isEmpty else { return nil }
        
        // 1. 找出历史记录中最后一次学过的 Lesson (按日期倒序查找)
        let sortedHistory = history.sorted { $0.dateString > $1.dateString }
        if let lastLearned = sortedHistory.first(where: { $0.learnedLesson != nil })?.learnedLesson {
            
            // 2. 找到这个 Lesson 在当前服务器文件夹列表里的位置
            if let currentIndex = availableFolders.firstIndex(of: lastLearned) {
                let nextIndex = currentIndex + 1
                
                // 3. 判断是否到了最后一个。如果是，重头开始；如果不是，返回下一个。
                if nextIndex < availableFolders.count {
                    return availableFolders[nextIndex]
                } else {
                    return availableFolders[0] // 循环回到第一个
                }
            }
        }
        
        // 如果从来没学过，或者服务器换了新列表找不到旧记录，默认从第一个开始
        return availableFolders[0]
    }
    
    // 辅助：日期格式化
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 开发调试工具
    func resetHistory() {
        self.history = []
        try? FileManager.default.removeItem(at: fileURL)
        print("所有学习记录已清空！")
    }
}
