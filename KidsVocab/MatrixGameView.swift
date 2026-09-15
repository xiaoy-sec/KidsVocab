import SwiftUI

struct MatrixGameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var speechMgr = SpeechManager.shared
    
    // 数据
    @State private var levels: [MatrixLevel] = []
    @State private var currentLevelIndex = 0
    @State private var isLoading = true
    @State private var debugInfo = ""
    @State private var isPlaying = false
    
    // 游戏状态
    @State private var matchedOption: MatrixOption? = nil // 填入答案的用户选项
    @State private var showResult = false
    
    // 关卡选择列表的网格
    let levelColumns = [GridItem(.adaptive(minimum: 80), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：清新的薄荷绿
                Color(red: 235/255, green: 250/255, blue: 245/255).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("正在生成逻辑矩阵...")
                        .foregroundColor(.black) // 强制黑色loading
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
        // 🌟 核心修复1：强制浅色模式，防止深色模式下文字变白看不见
        .preferredColorScheme(.light)
        .task { await loadData() }
    }
    
    // MARK: - 关卡选择
    var LevelSelectionView: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.teal) // 强制青色
                }
                Spacer()
                Text("矩阵推理")
                    .font(.title2.bold())
                    .foregroundColor(.black) // 强制黑色
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
                                .background(Circle().fill(Color.teal.gradient).shadow(radius: 4))
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
            
            // 🌟 布局比例优化：
            // 横屏时，高度宝贵，矩阵区稍微给小一点比例，防止撑满
            let matrixAreaHeight = geo.size.height * (isLandscape ? 0.55 : 0.60)
            
            VStack(spacing: 0) {
                // 1. 顶部导航
                HStack {
                    Button(action: { withAnimation { isPlaying = false } }) {
                        HStack(spacing: 5) {
                            Image(systemName: "grid.circle.fill")
                            Text("列表")
                        }
                        .font(.headline)
                        .foregroundColor(.teal) // 🌟 强制青色，防止深色模式看不见
                        .padding(8)
                        .background(Capsule().fill(Color.white))
                        .shadow(radius: 2)
                    }
                    Spacer()
                    Text(currentLevel.prompt) // 题目提示
                        .font(.headline)
                        .foregroundColor(.black.opacity(0.8)) // 🌟 强制深灰色
                        .multilineTextAlignment(.center)
                    Spacer()
                    Button(action: { playPrompt() }) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.title)
                            .foregroundColor(.teal)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 2. 矩阵显示区 (Matrix)
                ZStack {
                    // 大背景卡片
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    
                    // 网格计算逻辑
                    let is3x3 = currentLevel.matrix_items.count > 4
                    let cols = is3x3 ? 3 : 2
                    let rows = is3x3 ? 3 : 2
                    
                    let gridLayout = Array(repeating: GridItem(.flexible(), spacing: 15), count: cols)
                    
                    LazyVGrid(columns: gridLayout, spacing: 15) {
                        ForEach(Array(currentLevel.matrix_items.enumerated()), id: \.offset) { index, item in
                            
                            // 🌟🌟🌟 核心修复2：横屏防爆算法 🌟🌟🌟
                            // 以前只根据宽度算，横屏时宽度大，格子就巨大，导致高度溢出。
                            // 现在同时计算“宽度允许的最大值”和“高度允许的最大值”，取最小值。
                            
                            // 1. 根据宽度算的尺寸
                            let availableW = geo.size.width - 100 // 左右边距
                            let sizeByWidth = availableW / CGFloat(cols)
                            
                            // 2. 根据高度算的尺寸 (高度 - 上下padding - 间隙) / 行数
                            let availableH = matrixAreaHeight - 60
                            let sizeByHeight = availableH / CGFloat(rows)
                            
                            // 3. 取两者较小值，并限制最大上限
                            let finalSize = min(min(sizeByWidth, sizeByHeight), 260)
                            
                            if item == "?" {
                                QuestionSlot(size: finalSize)
                            } else {
                                MatrixItemCard(imageName: item, size: finalSize)
                            }
                        }
                    }
                    // 居中
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: matrixAreaHeight)
                
                Spacer()
                
                // 3. 底部选项区
                if !showResult {
                    // 选项区布局
                    let optionCount = CGFloat(currentLevel.options.count)
                    let totalSpacing = (optionCount - 1) * 20 + 40
                    let optionWidth = (geo.size.width - totalSpacing) / optionCount
                    
                    // 选项卡片大小限制：最大 200，或者高度允许的范围
                    let maxOptionH = (geo.size.height - matrixAreaHeight - 80) // 剩余高度减去边距
                    let finalOptionSize = min(min(optionWidth, maxOptionH), 200)
                    
                    HStack(spacing: 20) {
                        ForEach(currentLevel.options) { option in
                            if matchedOption?.id != option.id {
                                OptionCard(option: option, size: finalOptionSize)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    // 确保容器高度足够，不会切断阴影
                    .frame(height: finalOptionSize + 20)
                } else {
                    // 成功反馈
                    VStack(spacing: 20) {
                        Text("🎉 逻辑正确！")
                            .font(.largeTitle.bold())
                            .foregroundColor(.teal) // 强制颜色
                            .transition(.scale)
                        
                        Button("下一题") { nextLevel() }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .controlSize(.large)
                    }
                    .padding(.bottom, 50)
                    .frame(height: 180)
                }
            }
        }
    }
    
    // MARK: - 组件
    
    func MatrixItemCard(imageName: String, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(red: 245/255, green: 250/255, blue: 250/255))
            
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/matrix/images/\(imageName).webp") ?? "")
                .scaledToFit()
                .padding(8)
        }
        .frame(width: size, height: size)
    }
    
    func QuestionSlot(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .foregroundColor(.teal.opacity(0.4))
                )
            
            if let matched = matchedOption {
                MatrixItemCard(imageName: matched.image, size: size)
                    .transition(.scale)
            } else {
                Text("?")
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.teal.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .dropDestination(for: String.self) { items, location in
            guard let id = items.first else { return false }
            return handleDrop(optionId: id)
        }
    }
    
    func OptionCard(option: MatrixOption, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .teal.opacity(0.2), radius: 5, y: 3)
            
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/matrix/images/\(option.image).webp") ?? "")
                .scaledToFit()
                .padding(5)
        }
        .frame(width: size, height: size)
        .draggable(option.id) {
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/matrix/images/\(option.image).webp") ?? "")
                .scaledToFit()
                .frame(width: 80, height: 80)
        }
    }
    
    var ErrorView: some View {
        VStack {
            Text(debugInfo).foregroundColor(.red)
            Button("重试") { Task { await loadData() } }
        }
    }
    
    // MARK: - 逻辑
    var currentLevel: MatrixLevel { levels[currentLevelIndex] }
    
    func loadData() async {
        do {
            levels = try await NetworkLoader.loadMatrixLevels()
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
    
    func handleDrop(optionId: String) -> Bool {
            guard let option = currentLevel.options.first(where: { $0.id == optionId }) else { return false }
            
            if option.isAnswer {
                withAnimation(.spring()) {
                    matchedOption = option
                    showResult = true
                }
                speechMgr.speak(english: "Bingo", chinese: "答对了")
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
            withAnimation { isPlaying = false }
        }
    }
}
