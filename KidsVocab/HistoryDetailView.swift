import SwiftUI

struct HistoryDetailView: View {
    let dateStr: String
    let wordIDs: [String]
    @Environment(\.dismiss) var dismiss
    @ObservedObject var speechMgr = SpeechManager.shared
    
    @State private var items: [LearningItem] = []
    @State private var isLoading = true
    @State private var statusMessage = "正在准备..."
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景强制白色
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(statusMessage)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                } else if items.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("未找到记录")
                            .foregroundColor(.gray)
                        
                        Button("再次查找") {
                            Task { await executeSearch(force: true) }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(items) { item in
                                Button(action: {
                                    speechMgr.speak(english: item.name, chinese: item.chineseName)
                                }) {
                                    VStack {
                                        CachedAsyncImage(urlString: item.imageUrl)
                                            .scaledToFit()
                                            .padding(5)
                                            .frame(height: 120)
                                        
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundColor(.black)
                                        Text(item.chineseName)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("\(dateStr) 学习记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            // 🌟 核心逻辑：排队机制
            .task {
                await performSmartLoad()
            }
        }
    }
    
    // MARK: - 智能排队加载逻辑
    private func performSmartLoad() async {
        // 1. 先检查是否有人正在占用刷新通道
        // 如果 App 刚启动，isLoading 肯定是 true。我们就死等它变 false。
        // 这就避免了我们的请求被 guard 弹回来的问题。
        while CategoryManager.shared.isLoading {
            await MainActor.run {
                self.statusMessage = "正在等待同步完成..."
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 每 0.2 秒看一眼
        }
        
        // 2. 如果分类还没准备好，先强制刷新一次
        if CategoryManager.shared.categories.isEmpty {
            await MainActor.run { self.statusMessage = "正在加载分类..." }
            await CategoryManager.shared.refreshCategories()
        }

        // 3. 现在通道空闲了，我们可以安全地执行我们的查找了
        await executeSearch(force: false)
        
        // 3. 双重保险：如果刚才那波加载居然没把数据带回来（极小概率），那我们自己再强制刷一次
        if items.isEmpty {
            await MainActor.run { self.statusMessage = "正在深度查找..." }
            await executeSearch(force: true)
        }
    }
    
    // MARK: - 查找逻辑
    private func executeSearch(force: Bool) async {
        await MainActor.run { self.isLoading = true }
        
        // 如果是强制刷新，且当前没有在加载，才去触发刷新
        if force && !CategoryManager.shared.isLoading {
            await CategoryManager.shared.refreshCategories()
        }
        
        let allCategories = CategoryManager.shared.categories
        var results: [LearningItem] = []
        
        await withTaskGroup(of: [LearningItem].self) { group in
            for cat in allCategories {
                group.addTask {
                    let catItems = await NetworkLoader.loadRemoteItems(folder: cat.folderName)
                    return catItems.filter { self.wordIDs.contains($0.name) }
                }
            }
            for await matched in group {
                results.append(contentsOf: matched)
            }
        }
        
        // 去重
        var uniqueResults: [LearningItem] = []
        for item in results {
            if !uniqueResults.contains(where: { $0.name == item.name }) {
                uniqueResults.append(item)
            }
        }
        
        let finalItems = uniqueResults
        await MainActor.run {
            self.items = finalItems
            self.isLoading = false
        }
    }
}
