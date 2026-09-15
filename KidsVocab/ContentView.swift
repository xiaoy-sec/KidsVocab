import SwiftUI
//test
// MARK: - 主入口视图
// ContentView.swift

struct MainTabView: View {
    init() {
        let capacity = 1024 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: capacity, diskPath: "kids_english_cache")
    }
    
    var body: some View {
        TabView {
            // 1. 单词
            ContentView()
                .tabItem { Label("图片单词", systemImage: "book.fill") }
            
            // 2. Ogden 850 word vocabulary
            OgdenVocabView()
                .tabItem { Label("基础单词", systemImage: "text.book.closed.fill") }
            
            // 3. 思维逻辑
            LogicHomeView()
                .tabItem { Label("思维", systemImage: "puzzlepiece.fill") }
            
            // 4. 设置
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .accentColor(.green)
    }
}

// MARK: - 单词首页
struct ContentView: View {
    @ObservedObject var categoryMgr = CategoryManager.shared
    @ObservedObject var historyMgr = HistoryManager.shared
    
    // 控制每日任务页面的弹出
    @State private var showDailyTask = false
    
    let columns = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
    let cardColors: [Color] = [.orange, .blue, .green, .purple, .pink, .yellow, .cyan, .indigo]

    // 1. 计算总词数
    private var totalWordCount: Int {
        categoryMgr.categories.reduce(0) { $0 + $1.itemCount }
    }
    
    // 2. 计算已掌握词数
    private var masteredWordCount: Int {
        historyMgr.getAllLearnedWordNames().count
    }
    
    // 3. 动态生成标题字符串
    private var dynamicTitle: String {
        return "一一学英语 (总词数:\(totalWordCount) 已掌握:\(masteredWordCount))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // === 每日打卡模块 ===
                    VStack(spacing: 15) {
                        CalendarView()
                        
                        Button(action: {
                            showDailyTask = true
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("开始今日挑战")
                                        .font(.headline)
                                    Text("完成4关，赢取金色徽章！")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(
                                (isTodayCompleted() ? Color.yellow : Color.green)
                                    .gradient
                            )
                            .cornerRadius(15)
                            .shadow(radius: 5)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 10)
                    
                    Divider().padding(.horizontal, 25)
                    
                    // === 分类列表模块 ===
                    if categoryMgr.isLoading && categoryMgr.categories.isEmpty {
                        ProgressView("同步中...").padding(.top, 50)
                    } else {
                        LazyVGrid(columns: columns, spacing: 25) {
                            ForEach(Array(categoryMgr.categories.enumerated()), id: \.element.id) { index, category in
                                NavigationLink(destination: destinationView(for: category)) {
                                    categoryCard(category: category, index: index)
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    SpeechManager.shared.speak(english: category.folderName, chinese: category.title.components(separatedBy: " ").last ?? "")
                                })
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(25)
                    }
                }
            }
            // 🌟 核心修改：这里设置标题
            .navigationTitle(dynamicTitle)
            // ❌ 删掉了 .navigationBarTitleDisplayMode(.inline)
            // ✅ 让它保持默认的大标题模式，这样最显眼！
            
            .refreshable { await categoryMgr.refreshCategories() }
            .task { if categoryMgr.categories.isEmpty { await categoryMgr.refreshCategories() } }
            .fullScreenCover(isPresented: $showDailyTask) {
                DailyTaskView()
            }
        }
    }

    // 辅助：检查今天是否已完成
    private func isTodayCompleted() -> Bool {
        let todayStr = formatDate(Date())
        return historyMgr.history.contains { $0.dateString == todayStr && $0.isCompleted }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func destinationView(for category: Category) -> some View {
        if category.folderName == "body" {
            BodyLearningView(category: category)
        } else {
            DetailGridView(category: category)
        }
    }

    private func categoryCard(category: Category, index: Int) -> some View {
        VStack(spacing: 15) {
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: category.iconPath) ?? "")
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            Text("\(category.title) (\(category.itemCount))")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity).frame(height: 180)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardColors[index % cardColors.count].gradient))
        .shadow(radius: 5)
    }
}
