import SwiftUI

struct ConversationView: View {
    @StateObject var manager = ConversationManager.shared
    
    var body: some View {
        List {
            ForEach(manager.lessons) { lesson in
                NavigationLink(value: lesson) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.title).font(.headline)
                        Text("\(lesson.script.count) 句对话").font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        // 🌟 核心改进：增加下拉刷新功能
        .refreshable {
            await manager.loadLessons()
        }
        .navigationDestination(for: ConversationLesson.self) { lesson in
            DialogueStageView(lesson: lesson)
        }
        .navigationTitle("情景对话")
        .task { // 🌟 使用 task 代替 onAppear，更符合现代 SwiftUI 异步加载规范
            if manager.lessons.isEmpty {
                await manager.loadLessons()
            }
        }
    }
}
