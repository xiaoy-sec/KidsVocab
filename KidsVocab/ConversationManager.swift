import Foundation
import SwiftUI
import Combine

@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    @Published var lessons: [ConversationLesson] = []
    @Published var isLoading: Bool = false
    
    private init() {}
    
    func loadLessons() async {
        guard !isLoading else { return }
        self.isLoading = true
        
        let folders = await NetworkLoader.discoverConversationFolders()
        var loadedLessons: [ConversationLesson] = []
        
        for folder in folders {
            let relativePath = "conversations/\(folder)/script.json"
            if let url = ResourceLocator.localOrRemoteURL(relativePath: relativePath),
               let lesson = await fetchLesson(url: url) {
                loadedLessons.append(lesson)
            }
        }
        
        // 🌟 只有成功拿到数据才替换，失败则保留旧数据，防止变白
        if !loadedLessons.isEmpty {
            self.lessons = loadedLessons
        }
        self.isLoading = false
    }

    private func fetchLesson(url: URL) async -> ConversationLesson? {
        do {
            if url.isFileURL {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(ConversationLesson.self, from: data)
            }
            // 对话脚本保持实时更新检查
            // REMOTE DISABLED: previously fetched conversation script from server.
            // let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            // let (data, _) = try await URLSession.shared.data(for: request)
            // return try JSONDecoder().decode(ConversationLesson.self, from: data)
            return nil
        } catch {
            return nil
        }
    }
}
