import SwiftUI

struct RavenTestGameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var speechMgr = SpeechManager.shared
    
    // 数据
    @State private var levels: [RavenLevel] = []
    @State private var currentLevelIndex = 0
    @State private var isLoading = true
    @State private var debugInfo = ""
    @State private var isPlaying = false
    
    // 答题状态
    @State private var selectedAnswer: Int? = nil
    @State private var isCorrect: Bool = false
    @State private var showFeedback: Bool = false
    
    let levelColumns = [GridItem(.adaptive(minimum: 80), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：沉稳的深空灰/蓝，专注答题
                Color(red: 240/255, green: 242/255, blue: 245/255).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("正在加载测试卷...").foregroundColor(.black)
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
        .preferredColorScheme(.light)
        .task { await loadData() }
    }
    
    // MARK: - 关卡选择列表
    var LevelSelectionView: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.largeTitle).foregroundColor(.indigo)
                }
                Spacer()
                Text("瑞文推理测试 (\(levels.count)题)")
                    .font(.title2.bold())
                    .foregroundColor(.black)
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
                                .background(Circle().fill(Color.indigo.gradient).shadow(radius: 4))
                        }
                    }
                }
                .padding(30)
            }
        }
    }
    
    // MARK: - 游戏主界面
    var GameInterface: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            VStack(spacing: 0) {
                // 1. 顶部导航
                HStack {
                    Button(action: { withAnimation { isPlaying = false } }) {
                        HStack(spacing: 5) { Image(systemName: "grid.circle.fill"); Text("列表") }
                            .foregroundColor(.indigo)
                            .padding(8).background(Capsule().fill(.white)).shadow(radius: 2)
                    }
                    Spacer()
                    Text("第 \(currentLevelIndex + 1) / \(levels.count) 题")
                        .font(.headline)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.indigo.opacity(0.1)))
                        .foregroundColor(.indigo)
                    Spacer()
                    Text("列表").hidden() // 占位保持居中
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 2. 题目大图展示区 (利用缩放保持比例)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    
                    CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/raven/images/\(currentLevel.image).webp") ?? "")
                        .scaledToFit()
                        .padding(20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .frame(maxHeight: .infinity) // 占据大部分空间
                
                // 3. 底部答题按钮区
                VStack(spacing: 15) {
                    Text("请选择正确的序号")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // 动态生成数字按钮，如果是8个选项，就换成2行，6个就1行（看屏幕宽度）
                    // 我们用 LazyVGrid 来自动排版
                    let cols = isLandscape ? currentLevel.option_count : (currentLevel.option_count > 6 ? 4 : 3)
                    let gridLayout = Array(repeating: GridItem(.flexible(), spacing: 15), count: cols)
                    
                    LazyVGrid(columns: gridLayout, spacing: 15) {
                        ForEach(1...currentLevel.option_count, id: \.self) { number in
                            NumberButton(number: number)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
                .frame(height: isLandscape ? 150 : 200) // 底部固定高度
                .background(Color.white.ignoresSafeArea(edges: .bottom))
                .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                
                // 答题反馈浮层 (全屏遮罩)
                if showFeedback {
                    FeedbackOverlay()
                }
            }
        }
    }
    
    // MARK: - 组件
    
    // 数字按钮// MARK: - 组件
    
    // 数字按钮
    func NumberButton(number: Int) -> some View {
        let isSelected = selectedAnswer == number
        // (注：删除了 isRight 的判断，因为不需要提前显示正确答案了)
        
        // 状态颜色
        var bgColor = Color.indigo.opacity(0.1)
        var fgColor = Color.indigo
        
        if showFeedback {
            if isSelected {
                // 只对当前选中的按钮变色：对的变绿，错的变红
                bgColor = isCorrect ? Color.green : Color.red
                fgColor = Color.white
            }
            // 🚫 删除了原本在这里的 else if isRight 逻辑，不再把正确答案标绿
        }
        
        return Button(action: {
            guard !showFeedback else { return } // 锁住按钮
            checkAnswer(selected: number)
        }) {
            Text("\(number)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(fgColor)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(RoundedRectangle(cornerRadius: 15).fill(bgColor))
                // 未判定时加点投影
                .shadow(color: showFeedback ? .clear : .indigo.opacity(0.2), radius: 5, y: 2)
        }
    }
    
    // 反馈动画层
    func FeedbackOverlay() -> some View {
        ZStack {
            Color.white.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(isCorrect ? .green : .red)
                    // 简单的心跳动画
                    .scaleEffect(isCorrect ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showFeedback)
                
                Text(isCorrect ? "答对啦！" : "再想想哦~")
                    .font(.largeTitle.bold())
                    .foregroundColor(isCorrect ? .green : .red)
            }
        }
    }
    
    var ErrorView: some View {
        VStack { Text(debugInfo).foregroundColor(.red); Button("重试") { Task { await loadData() } } }
    }
    
    // MARK: - 逻辑
    var currentLevel: RavenLevel { levels[currentLevelIndex] }
    
    func loadData() async {
        do {
            levels = try await NetworkLoader.loadRavenLevels()
            isLoading = false
        } catch {
            debugInfo = "加载失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func enterLevel(index: Int) {
        currentLevelIndex = index
        resetState()
        withAnimation { isPlaying = true }
    }
    
    func resetState() {
        selectedAnswer = nil
        showFeedback = false
        isCorrect = false
    }
    
    func checkAnswer(selected: Int) {
            selectedAnswer = selected
            isCorrect = (selected == currentLevel.correct_answer)
            
            if isCorrect {
                speechMgr.speak(english: "Bingo", chinese: "答对了")
            } else {
                speechMgr.speak(english: "Try again", chinese: "再试一次")
            }
            
            withAnimation { showFeedback = true }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    if isCorrect {
                        if currentLevelIndex < levels.count - 1 {
                            currentLevelIndex += 1
                            resetState()
                        } else {
                            isPlaying = false
                        }
                    } else {
                        resetState()
                    }
                }
            }
        }
}
