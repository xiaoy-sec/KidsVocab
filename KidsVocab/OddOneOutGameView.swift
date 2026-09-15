import SwiftUI

struct OddOneOutGameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var speechMgr = SpeechManager.shared
    
    // 数据状态
    @State private var levels: [LogicLevel] = []
    @State private var currentLevelIndex = 0
    @State private var isLoading = true
    @State private var debugInfo: String = ""
    
    // 视图状态：控制是显示“关卡列表”还是“游戏界面”
    @State private var isPlaying = false
    
    // 动画状态
    @State private var shakeItemId: UUID? = nil
    @State private var isSuccessAnim = false
    
    // 布局定义
    let levelColumns = [GridItem(.adaptive(minimum: 80), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 🌟 1. 背景：强制浅米色 (不受深色模式影响)
                Color(red: 250/255, green: 248/255, blue: 240/255).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("正在加载关卡...")
                        .foregroundColor(.black) // 强制黑色 loading
                } else if levels.isEmpty {
                    ErrorView
                } else if isPlaying {
                    // === 游戏主界面 ===
                    GameContentView
                } else {
                    // === 关卡选择界面 ===
                    LevelSelectionView
                }
            }
            // 隐藏系统默认导航栏，用我们自定义的
            .navigationBarHidden(true)
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - 关卡选择界面
    var LevelSelectionView: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("选择关卡")
                    .font(.title2.bold())
                    .foregroundColor(.black) // 🌟 强制黑色
                Spacer()
                // 占位，保持标题居中
                Image(systemName: "arrow.left.circle.fill").hidden()
            }
            .padding()
            
            ScrollView {
                LazyVGrid(columns: levelColumns, spacing: 20) {
                    ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                        Button(action: {
                            enterLevel(index: index)
                        }) {
                            VStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(Color.orange.gradient)
                                    .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 4)
                            )
                        }
                    }
                }
                .padding(30)
            }
        }
    }
    
    // MARK: - 游戏进行中界面
    var GameContentView: some View {
        VStack {
            if isSuccessAnim {
                SuccessView
            } else {
                // 1. 顶部栏
                HStack {
                    // 返回关卡列表
                    Button(action: {
                        withAnimation { isPlaying = false }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "grid.circle.fill")
                            Text("列表")
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Capsule().fill(Color.white))
                        .shadow(radius: 2)
                    }
                    
                    Spacer()
                    
                    Text("关卡 \(currentLevelIndex + 1)/\(levels.count)")
                        .font(.headline)
                        .foregroundColor(.black) // 🌟 强制黑色
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                    
                    Spacer()
                    
                    // 重听按钮
                    Button(action: { playPrompt() }) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 2. 题目文字
                Text(currentLevel.prompt)
                    .font(.title2.bold())
                    .foregroundColor(.black.opacity(0.8)) // 🌟 强制深灰色
                    .padding(.vertical, 10)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 3. 核心游戏区域
                GeometryReader { geo in
                    let spacing: CGFloat = 20
                    let width = (geo.size.width - spacing * 3) / 2
                    let height = (geo.size.height - spacing * 2) / 2
                    
                    LazyVGrid(columns: [GridItem(.fixed(width)), GridItem(.fixed(width))], spacing: spacing) {
                        ForEach(currentLevel.items) { item in
                            CardView(item: item, width: width, height: height)
                        }
                    }
                    .padding(spacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    // MARK: - 组件
    
    var ErrorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("暂无关卡")
                .font(.headline)
                .foregroundColor(.black) // 强制黑色
            
            if !debugInfo.isEmpty {
                Text(debugInfo)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(10)
            }
            
            Button("重试") {
                isLoading = true
                Task { await loadData() }
            }
            .buttonStyle(.bordered)
        }
    }
    
    func CardView(item: LogicItem, width: CGFloat, height: CGFloat) -> some View {
        let imgUrl = ResourceLocator.localOrRemoteURLString(relativePath: "logic/classification/odd_one_out/images/\(item.image).webp") ?? ""
        
        return Button(action: {
            handleTap(item)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, y: 5)
                
                CachedAsyncImage(urlString: imgUrl)
                    .scaledToFit()
                    .padding(15)
            }
            .frame(width: width, height: height)
            .offset(x: shakeItemId == item.id ? 10 : 0)
            .animation(.default, value: shakeItemId)
        }
    }
    
    var SuccessView: some View {
        VStack(spacing: 30) {
            Image("success_badge")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
            
            Text("恭喜通关本局！")
                .font(.largeTitle.bold())
                .foregroundColor(.black) // 强制黑色
            
            HStack(spacing: 20) {
                Button("返回列表") {
                    withAnimation {
                        isSuccessAnim = false
                        isPlaying = false
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                if currentLevelIndex < levels.count - 1 {
                    Button("下一关") {
                        withAnimation { isSuccessAnim = false }
                        enterLevel(index: currentLevelIndex + 1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
    }
    
    // MARK: - 逻辑处理
    
    var currentLevel: LogicLevel { levels[currentLevelIndex] }
    
    func loadData() async {
        do {
            let fetched = try await NetworkLoader.loadOddOneOutLevels()
            await MainActor.run {
                self.levels = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.debugInfo = "加载失败：\(error.localizedDescription)"
            }
        }
    }
    
    func enterLevel(index: Int) {
        currentLevelIndex = index
        withAnimation {
            isPlaying = true
        }
        // 稍微延迟播放语音，体验更好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            playPrompt()
        }
    }
    
    func playPrompt() {
        guard !levels.isEmpty else { return }
        speechMgr.speak(english: "", chinese: currentLevel.prompt)
    }
    
    func handleTap(_ item: LogicItem) {
            if item.isAnswer {
                speechMgr.speak(english: "Bingo", chinese: "答对了")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if currentLevelIndex < levels.count - 1 {
                        withAnimation { currentLevelIndex += 1 }
                        playPrompt()
                    } else {
                        withAnimation { isSuccessAnim = true }
                        speechMgr.speak(english: "Great job", chinese: "太棒了")
                    }
                }
            } else {
                withAnimation(.default) { shakeItemId = item.id }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shakeItemId = nil }
                speechMgr.speak(english: "try again", chinese: "再试一次")
            }
        }
}
