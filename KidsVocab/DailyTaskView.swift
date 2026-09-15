import SwiftUI

struct DailyTaskView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var historyMgr = HistoryManager.shared
    @ObservedObject var speechMgr = SpeechManager.shared
    
    // 游戏阶段
    enum GameStage {
        case loading    // 抽题中
        case review     // 复习昨日
        case learn      // 1. 认图识字
        case listenEN   // 2. 听音辨图 (英)
        case listenCN   // 3. 听音辨图 (中)
        case exam       // 4. 连线大闯关
        case success    // 结算
    }
    
    @State private var stage: GameStage = .loading
    @State private var todayWords: [LearningItem] = []
    @State private var reviewWords: [LearningItem] = []
    
    // 连线游戏专用状态
    @State private var leftItems: [LearningItem] = []
    @State private var rightItems: [LearningItem] = []
    @State private var selectedLeftId: UUID? = nil
    @State private var matchedIds: Set<UUID> = []
    @State private var isWrongAnim: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：淡雅的冰蓝色背景
                Color(red: 242/255, green: 246/255, blue: 250/255)
                    .ignoresSafeArea()
                
                switch stage {
                case .loading:
                    ProgressView("正在生成今日挑战...", value: 0.5)
                        .scaleEffect(1.2)
                case .review:
                    ReviewStageView(words: reviewWords) { nextStage(.learn) }
                case .learn:
                    LearningStageView(words: todayWords, title: "第1关：看图学词") { nextStage(.listenEN) }
                case .listenEN:
                    LearningStageView(words: todayWords, title: "第2关：听音 (英)", hideText: true, playMode: .englishOnly) { nextStage(.listenCN) }
                case .listenCN:
                    LearningStageView(words: todayWords, title: "第3关：听音 (中)", hideText: true, hideImage: true, playMode: .chineseOnly) { nextStage(.exam) }
                case .exam:
                    ExamMatchingView
                case .success:
                    SuccessView
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if stage != .success {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("放弃") { dismiss() }
                    }
                }
            }
        }
        .task { await prepareDailyData() }
        .preferredColorScheme(.light) // 强制浅色模式
    }
    
    private var navTitle: String {
        switch stage {
        case .loading: return "准备中"
        case .review: return "复习昨日"
        case .learn: return "第一关"
        case .listenEN: return "第二关"
        case .listenCN: return "第三关"
        case .exam: return "第四关：词义连线"
        case .success: return "打卡成功"
        }
    }
    
    private func nextStage(_ next: GameStage) {
        withAnimation {
            stage = next
            if next == .exam { setupExam() }
        }
    }
    
    // MARK: - 核心逻辑：抽题与数据准备
    private func prepareDailyData() async {
        var candidates: [LearningItem] = []
        let learnedSet = historyMgr.getAllLearnedWordNames()
        if CategoryManager.shared.categories.isEmpty {
            await CategoryManager.shared.refreshCategories()
        }
        let allCategories = CategoryManager.shared.categories.shuffled()
        let allItems = await loadUniqueItems(from: allCategories)
        let reviewItems = historyMgr.getReviewWords(allServerItems: allItems)
        
        // 1. 抽取 4 个新词
        for cat in allCategories {
            if candidates.count >= 4 { break }
            let items = await NetworkLoader.loadRemoteItems(folder: cat.folderName)
            let newItems = items.filter { !learnedSet.contains($0.name) && !containsLearningItem(candidates, $0) }
            if let randomOne = newItems.randomElement() { candidates.append(randomOne) }
        }
        
        if candidates.count < 4 {
            for cat in allCategories {
                if candidates.count >= 4 { break }
                let items = await NetworkLoader.loadRemoteItems(folder: cat.folderName)
                if let randomOne = items.filter({ !containsLearningItem(candidates, $0) }).randomElement() {
                    candidates.append(randomOne)
                }
            }
        }
        
        await MainActor.run {
            self.todayWords = Array(candidates.prefix(4))
            self.reviewWords = reviewItems
            self.stage = reviewItems.isEmpty ? .learn : .review
        }
    }
    
    private func loadUniqueItems(from categories: [Category]) async -> [LearningItem] {
        var results: [LearningItem] = []
        for category in categories {
            let items = await NetworkLoader.loadRemoteItems(folder: category.folderName)
            for item in items where !containsLearningItem(results, item) {
                results.append(item)
            }
        }
        return results
    }
    
    private func containsLearningItem(_ items: [LearningItem], _ target: LearningItem) -> Bool {
        items.contains { $0.stableID == target.stableID }
    }
    
    // MARK: - 1-3关：通用学习视图 (2x2网格)
    @ViewBuilder
    func LearningStageView(words: [LearningItem], title: String, hideText: Bool = false, hideImage: Bool = false, playMode: PlayMode = .normal, onNext: @escaping () -> Void) -> some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 50) / 2
            let availableHeight = geo.size.height - 180
            let cardHeight = availableHeight / 2
            
            VStack(spacing: 0) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                
                LazyVGrid(columns: [GridItem(.fixed(cardWidth)), GridItem(.fixed(cardWidth))], spacing: 15) {
                    ForEach(words) { item in
                        Button(action: {
                            playItem(item, mode: playMode)
                        }) {
                            VStack(spacing: 8) {
                                if hideImage {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.blue.opacity(0.8))
                                        .padding(30)
                                } else {
                                    CachedAsyncImage(urlString: item.imageUrl)
                                        .scaledToFit()
                                        .padding(5)
                                }
                                
                                if !hideText {
                                    VStack(spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                            .minimumScaleFactor(0.5)
                                        Text(item.chineseName)
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(height: 50)
                                } else {
                                    VStack(spacing: 2) {
                                        Text("???")
                                            .font(.title2.bold())
                                            .foregroundColor(.blue.opacity(0.3))
                                    }
                                    .frame(height: 50)
                                }
                            }
                            .frame(width: cardWidth, height: cardHeight)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                Button(action: onNext) {
                    Text("挑战下一关")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder
    func ReviewStageView(words: [LearningItem], onNext: @escaping () -> Void) -> some View {
        VStack {
            Text("先复习一下昨天的单词吧！").font(.headline).padding()
            List(words) { item in
                HStack {
                    CachedAsyncImage(urlString: item.imageUrl).frame(width: 50, height: 50)
                    VStack(alignment: .leading) {
                        Text(item.name).bold()
                        Text(item.chineseName).font(.caption)
                    }
                    Spacer()
                    Button(action: { speechMgr.speak(english: item.name, chinese: item.chineseName) }) {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            
            Button("我记住了，开始今日挑战", action: onNext)
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
    
    // MARK: - 第四关：连线匹配视图
    private func setupExam() {
        leftItems = todayWords.shuffled()
        rightItems = todayWords.shuffled()
        matchedIds = []
        selectedLeftId = nil
    }
    
    var ExamMatchingView: some View {
        VStack {
            Text("将左侧单词与右侧图片配对")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top)
            
            ScrollView {
                HStack(spacing: 50) {
                    // === 左侧：单词列 ===
                    VStack(spacing: 30) {
                        ForEach(leftItems) { item in
                            if !matchedIds.contains(item.id) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 30)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                                    
                                    if selectedLeftId == item.id {
                                        RoundedRectangle(cornerRadius: 30)
                                            .stroke(Color.blue, lineWidth: 6)
                                    }
                                    
                                    Text(item.name)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(width: 280, height: 180)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedLeftId = item.id
                                        speechMgr.speak(english: item.name, chinese: "")
                                    }
                                }
                                .scaleEffect(selectedLeftId == item.id ? 1.05 : 1.0)
                            } else {
                                Spacer().frame(width: 280, height: 180)
                            }
                        }
                    }
                    
                    // === 右侧：图片列 ===
                    VStack(spacing: 30) {
                        ForEach(rightItems) { item in
                            if !matchedIds.contains(item.id) {
                                Button(action: { checkMatch(rightItem: item) }) {
                                    CachedAsyncImage(urlString: item.imageUrl)
                                        .scaledToFit()
                                        .padding(20)
                                        .frame(width: 180, height: 180)
                                        .background(Color.white)
                                        .cornerRadius(30)
                                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                                }
                            } else {
                                Spacer().frame(width: 180, height: 180)
                            }
                        }
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(.top)
        .offset(x: isWrongAnim ? 10 : 0)
        .animation(.default, value: isWrongAnim)
    }
    
    private func checkMatch(rightItem: LearningItem) {
        guard let leftId = selectedLeftId else { return }
        
        if let leftItem = leftItems.first(where: { $0.id == leftId }) {
            if leftItem.name == rightItem.name {
                withAnimation { _ = matchedIds.insert(leftItem.id) }
                selectedLeftId = nil
                
                if matchedIds.count == todayWords.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        finishTask()
                    }
                }
            } else {
                isWrongAnim = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isWrongAnim = false }
                speechMgr.speak(english: "Try again", chinese: "再试一次")
            }
        }
    }
    
    // MARK: - 结算逻辑
    private func finishTask() {
        historyMgr.saveTodayRecord(words: todayWords)
        withAnimation { stage = .success }
    }
    
    // MARK: - 结算成功视图
    var SuccessView: some View {
        VStack(spacing: 30) {
            Image("success_badge")
                .resizable()
                .scaledToFit()
                .frame(height: 250)
                .shadow(radius: 10)
            
            Text("挑战成功！")
                .font(.largeTitle.bold())
                .foregroundColor(.black)
            
            Text("今日已掌握 \(todayWords.count) 个新单词")
                .font(.title3)
                .foregroundColor(.gray)
            
            Button("领取金色徽章") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
            .padding(.top, 20)
        }
    }
    
    enum PlayMode { case normal, englishOnly, chineseOnly }
    
    private func playItem(_ item: LearningItem, mode: PlayMode) {
        switch mode {
        case .normal: speechMgr.speak(english: item.name, chinese: item.chineseName)
        case .englishOnly: speechMgr.speak(english: item.name, chinese: "")
        case .chineseOnly: speechMgr.speak(english: "", chinese: item.chineseName)
        }
    }
}
