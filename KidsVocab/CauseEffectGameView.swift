import SwiftUI

struct CauseEffectGameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var speechMgr = SpeechManager.shared
    
    // 数据
    @State private var levels: [CauseEffectLevel] = []
    @State private var currentLevelIndex = 0
    @State private var isLoading = true
    @State private var debugInfo = ""
    @State private var isPlaying = false
    
    // 游戏状态
    @State private var matchedOption: CauseEffectOption? = nil // 用户拖进去的那个
    @State private var showResult = false // 是否显示最终结果图
    
    // 关卡选择列表的网格
    let levelColumns = [GridItem(.adaptive(minimum: 80), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：淡紫色
                Color(red: 245/255, green: 240/255, blue: 255/255).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("准备逻辑题...").foregroundColor(.black)
                } else if levels.isEmpty {
                    ErrorView
                } else if isPlaying {
                    GameInterface
                } else {
                    LevelSelectionView
                }
            }
            .navigationBarHidden(true)
        }
        .task { await loadData() }
    }
    
    // MARK: - 关卡选择
    var LevelSelectionView: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.largeTitle).foregroundColor(.purple)
                }
                Spacer()
                Text("因果推理").font(.title2.bold()).foregroundColor(.black)
                Spacer()
                Image(systemName: "arrow.left.circle.fill").hidden()
            }.padding()
            
            ScrollView {
                LazyVGrid(columns: levelColumns, spacing: 20) {
                    ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                        Button(action: { enterLevel(index: index) }) {
                            Text("\(index + 1)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(Circle().fill(Color.purple.gradient).shadow(radius: 4))
                        }
                    }
                }
                .padding(30)
            }
        }
    }
    
    // MARK: - 游戏主界面 (核心布局优化)
    var GameInterface: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            // 🌟 1. 计算布局尺寸
            // 顶部区域高度：占屏幕高度的 35% (竖屏) 或 45% (横屏)，留更多空间给下面
            let topAreaHeight = geo.size.height * (isLandscape ? 0.45 : 0.35)
            
            VStack(spacing: 0) {
                // --- 顶部导航 ---
                HStack {
                    Button(action: { withAnimation { isPlaying = false } }) {
                        HStack(spacing: 5) { Image(systemName: "grid.circle.fill"); Text("列表") }
                            .foregroundColor(.purple)
                            .padding(8).background(Capsule().fill(.white))
                    }
                    Spacer()
                    Text(currentLevel.title).font(.title3.bold()).foregroundColor(.black)
                    Spacer()
                    Button(action: { playPrompt() }) {
                        Image(systemName: "speaker.wave.2.circle.fill").font(.title).foregroundColor(.purple)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5) // 减少顶部留白
                
                // --- 核心互动区 (问题 + 答案框) ---
                VStack {
                    HStack(spacing: isLandscape ? 40 : 15) {
                        // 计算卡片尺寸：保证能放入 TopArea
                        // 宽度限制：不能超过屏幕的一半太远
                        let maxCardW = geo.size.width * 0.4
                        let maxCardH = topAreaHeight * 0.85
                        // 取长宽限制中较小的那个，保持比例
                        let cardSize = min(maxCardW, maxCardH)
                        
                        if showResult, let resultImg = currentLevel.result_image {
                            // 成功结果图 (放大一点)
                            ProblemCard(imageName: resultImg, text: "完美解决！", width: cardSize * 1.5, height: cardSize * 1.2)
                                .transition(.scale)
                        } else {
                            // 问题图
                            ProblemCard(imageName: currentLevel.question_image, text: "发生了什么？", width: cardSize, height: cardSize * 1.1)
                            
                            // 箭头
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: isLandscape ? 40 : 30))
                                .foregroundColor(.purple.opacity(0.5))
                            
                            // 接收框
                            AnswerSlot(width: cardSize, height: cardSize * 1.1)
                        }
                    }
                }
                .frame(height: topAreaHeight) // 固定高度区域
                .frame(maxWidth: .infinity)
                
                // --- 底部备选区 (自适应网格) ---
                if !showResult {
                    // 🌟 核心修改：动态计算底部卡片大小，防止过大
                    let availableWidth = geo.size.width
                    
                    // 决定网格列数：
                    // 横屏时：如果屏幕特别宽，也可以考虑 4 列防止卡片太大，但既然你要双列，我们限制每列的宽度
                    let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
                    
                    // 计算理想的卡片宽度
                    // 屏幕宽 / 2 - 间隙
                    let rawWidth = (availableWidth - 60) / 2
                    // 🌟 关键限制：卡片最大宽度不应超过 240，防止 iPad 上巨大化
                    let cardWidth = min(rawWidth, 240)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(currentLevel.options) { option in
                                if matchedOption?.id != option.id {
                                    DraggableOptionCard(option: option, width: cardWidth)
                                }
                            }
                        }
                        .padding(20)
                        // 让网格整体居中 (针对限制了宽度的 iPad)
                        .frame(maxWidth: isLandscape ? 600 : .infinity)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(20)
                    
                } else {
                    // 成功后的按钮
                    Spacer()
                    Button("下一关") {
                        nextLevel()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // MARK: - 组件
    
    // 问题卡片
    func ProblemCard(imageName: String, text: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/cause_effect/images/\(imageName).webp") ?? "")
                .scaledToFit()
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部文字条
            Text(text)
                .font(.system(size: height * 0.09, weight: .bold)) // 字体随高度变化
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, height * 0.08)
                .background(Color.purple.opacity(0.8))
        }
        .frame(width: width, height: height)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .purple.opacity(0.2), radius: 5)
    }
    
    // 答案插槽
    func AnswerSlot(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.5))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(style: StrokeStyle(lineWidth: 3, dash: [10]))
                        .foregroundColor(.purple.opacity(0.3))
                )
            
            if let matched = matchedOption {
                ProblemCard(imageName: matched.image, text: matched.text, width: width, height: height)
            } else {
                VStack {
                    Image(systemName: "hand.tap")
                        .font(.system(size: height * 0.2))
                        .foregroundColor(.purple.opacity(0.3))
                    Text("拖到这里")
                        .font(.system(size: height * 0.1))
                        .foregroundColor(.purple.opacity(0.3))
                }
            }
        }
        .dropDestination(for: String.self) { items, location in
            guard let uuid = items.first else { return false }
            return handleDrop(uuid: uuid)
        }
    }
    
    // 🌟 选项卡片 (限制了最大尺寸)
    func DraggableOptionCard(option: CauseEffectOption, width: CGFloat) -> some View {
        // 高度按比例，稍微矮一点点更紧凑
        let height = width * 1.0
        
        return VStack(spacing: 0) {
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/cause_effect/images/\(option.image).webp") ?? "")
                .scaledToFit()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Text(option.text)
                .font(.system(size: min(width * 0.12, 24), weight: .bold)) // 限制最大字号
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.purple)
        }
        .frame(width: width, height: height)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        .draggable(option.id.uuidString) {
            VStack {
                 CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/cause_effect/images/\(option.image).webp") ?? "")
                    .scaledToFit()
            }
            .frame(width: 80, height: 80)
            .background(Color.white)
            .cornerRadius(10)
            .onAppear { speechMgr.speak(english: "", chinese: option.text) }
        }
        .onTapGesture {
            speechMgr.speak(english: "", chinese: option.text)
        }
    }
    
    var ErrorView: some View {
        VStack { Text(debugInfo).foregroundColor(.red); Button("重试") { Task { await loadData() } } }
    }
    
    // MARK: - 逻辑
    var currentLevel: CauseEffectLevel { levels[currentLevelIndex] }
    
    func loadData() async {
        do {
            levels = try await NetworkLoader.loadCauseEffectLevels()
            isLoading = false
        } catch {
            debugInfo = "加载失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func enterLevel(index: Int) {
        currentLevelIndex = index
        matchedOption = nil
        showResult = false
        withAnimation { isPlaying = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playPrompt() }
    }
    
    func playPrompt() {
        speechMgr.speak(english: "", chinese: currentLevel.prompt)
    }
    
    func handleDrop(uuid: String) -> Bool {
            guard let option = currentLevel.options.first(where: { $0.id.uuidString == uuid }) else { return false }
            
            if option.isAnswer {
                withAnimation {
                    matchedOption = option
                }
                speechMgr.speak(english: "Bingo", chinese: "答对了")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { showResult = true }
                    speechMgr.speak(english: "Great job", chinese: "太棒了")
                }
                return true
            } else {
                speechMgr.speak(english: "Try again", chinese: "再试一次")
                return false
            }
        }
    
    func nextLevel() {
        if currentLevelIndex < levels.count - 1 {
            enterLevel(index: currentLevelIndex + 1)
        } else {
            withAnimation { isPlaying = false } // 结束
        }
    }
}
