import SwiftUI
import Combine
import Foundation

struct DetailGridView: View {
    let category: Category
    @State private var items: [LearningItem] = []
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
                ForEach(items) { item in
                    Button(action: { 
                        Task { await playWordAudio(item) }
                    }) {
                        VStack(spacing: 15) {
                            CachedAsyncImage(urlString: item.imageUrl)
                                .scaledToFit()
                                .frame(height: 120)
                            
                            VStack(spacing: 5) {
                                // 🌟 1. 自动适配：浅色模式变黑，暗色模式变白
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                // 🌟 2. 自动适配：浅色深灰，暗色浅灰
                                Text(item.chineseName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        // 🌟 3. 关键：这个颜色在暗色模式下会自动变成深灰色
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        // 🌟 4. 阴影在暗色模式下也要淡一点，才自然
                        .shadow(color: Color.black.opacity(0.15), radius: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(30)
        }
        .navigationTitle(category.title)
        // 🌟 5. 确保整个页面的背景也是自适应的
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            self.items = await NetworkLoader.loadRemoteItems(folder: category.folderName)
        }
    }
    
    private func playWordAudio(_ item: LearningItem) async {
        let text = item.name
        let chineseText = item.chineseName
        
        // 停止当前播放
        SpeechManager.shared.stop()
        
        // 统一使用本地语音朗读英文和中文
        SpeechManager.shared.speak(english: text, chinese: chineseText)
    }
}
