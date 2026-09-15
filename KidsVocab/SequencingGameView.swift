import SwiftUI
import AVKit

struct SequencingGameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var speechMgr = SpeechManager.shared
    
    // 数据状态
    @State private var levels: [SequenceLevel] = []
    @State private var currentLevelIndex = 0
    @State private var isLoading = true
    @State private var debugInfo = ""
    
    // 视图状态
    @State private var isPlaying = false
    
    // 游戏状态
    @State private var userSlots: [SequenceStep?] = []
    @State private var availableCards: [SequenceStep] = []
    @State private var showSuccessVideo = false
    @State private var player: AVPlayer?
    
    // 关卡选择网格列数
    let levelColumns = [GridItem(.adaptive(minimum: 80), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：淡蓝色
                Color(red: 240/255, green: 248/255, blue: 255/255).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("准备故事板...")
                        .foregroundColor(.black)
                } else if levels.isEmpty {
                    ErrorView
                } else if isPlaying {
                    if showSuccessVideo {
                        SuccessVideoOverlay
                    } else {
                        GameInterface
                    }
                } else {
                    LevelSelectionView
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - 关卡选择界面
    var LevelSelectionView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("选择故事")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                Spacer()
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
                                    .fill(Color.blue.gradient)
                                    .shadow(color: .blue.opacity(0.4), radius: 4, x: 0, y: 4)
                            )
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
            // 🌟 1. 判断屏幕方向
            let isLandscape = geo.size.width > geo.size.height
            
            VStack(spacing: 0) {
                // --- 顶部导航 ---
                HStack {
                    Button(action: { withAnimation { isPlaying = false } }) {
                        HStack(spacing: 5) {
                            Image(systemName: "grid.circle.fill")
                            Text("列表")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Capsule().fill(Color.white))
                    }
                    Spacer()
                    Text(currentLevel.title).font(.title3.bold()).foregroundColor(.black)
                    Spacer()
                    Text("列表").hidden()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // --- 上方插槽区域 ---
                let slotCount = CGFloat(currentLevel.steps.count)
                let slotSpacing: CGFloat = 10
                let totalSlotSpacing = (slotCount - 1) * slotSpacing
                
                // 限制插槽区域的最大宽度，防止横屏时拉得太长
                let maxSlotAreaWidth = isLandscape ? geo.size.width * 0.7 : geo.size.width - 40
                let slotWidth = (maxSlotAreaWidth - totalSlotSpacing) / slotCount
                let slotHeight = min(slotWidth, 120) // 限制最大高度
                
                HStack(spacing: slotSpacing) {
                    ForEach(0..<currentLevel.steps.count, id: \.self) { index in
                        SlotView(index: index, content: userSlots.indices.contains(index) ? userSlots[index] : nil, size: slotHeight)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.5))
                .padding(.vertical, 10)
                
                // --- 播放按钮 (悬浮) ---
                ZStack {
                    if isSlotsFull {
                        Button(action: checkAnswer) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.white))
                                .shadow(radius: 10)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(100)
                    }
                }
                .frame(height: isSlotsFull ? 100 : 20)
                
                // --- 下方待选卡片区域 (自适应核心) ---
                // 🌟 核心逻辑：横屏用4列，竖屏用2列
                let columnsCount = isLandscape ? 4 : 2
                let gridLayout = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnsCount)
                
                // 计算每个卡片的宽度：(屏幕宽 - 左右边距(40) - 中间间距) / 列数
                let totalGridSpacing = CGFloat(columnsCount - 1) * 20
                let cardWidth = (geo.size.width - 40 - totalGridSpacing) / CGFloat(columnsCount)
                
                ScrollView {
                    LazyVGrid(columns: gridLayout, spacing: 20) {
                        ForEach(availableCards) { card in
                            DraggableCard(card: card, width: cardWidth)
                        }
                    }
                    .padding(20)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - 组件
    
    // 插槽视图
    func SlotView(index: Int, content: SequenceStep?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(style: Style.dash)
                        .foregroundColor(.gray.opacity(0.5))
                )
            
            if let step = content {
                // 插槽里的卡片：传入的是小尺寸 (size)
                CardContent(step: step, size: size)
                    .onTapGesture {
                        speechMgr.speak(english: "", chinese: step.text)
                        returnCardToPool(step, at: index)
                    }
            } else {
                Text("\(index + 1)")
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.2))
            }
        }
        .dropDestination(for: String.self) { items, location in
            guard let uuidStr = items.first else { return false }
            handleDrop(uuidStr: uuidStr, to: index)
            return true
        }
    }
    
    // 待选区的卡片
    func DraggableCard(card: SequenceStep, width: CGFloat) -> some View {
        CardContent(step: card, size: width)
            .draggable(card.id.uuidString) {
                // 拖拽时的预览图 (固定为小尺寸 100)
                CardContent(step: card, size: 100)
                    .onAppear { speechMgr.speak(english: "", chinese: card.text) }
            }
            .onTapGesture {
                speechMgr.speak(english: "", chinese: card.text)
            }
    }

    // 通用卡片内容 (文字大小自适应)
    func CardContent(step: SequenceStep, size: CGFloat) -> some View {
        // 判断是否是大卡片模式 (底部待选区通常较大)
        let isBigCard = size > 130
        
        return VStack(spacing: 0) {
            CachedAsyncImage(urlString: ResourceLocator.localOrRemoteURLString(relativePath: "logic/sequencing/images/\(step.image).webp") ?? "")
                .scaledToFit()
                // 大卡片留白多一点，好看；小卡片留白少，利用空间
                .padding(isBigCard ? 15 : 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Text(step.text)
                // 🌟 字体限制：最大不超过 22，否则iPad上字太大了
                .font(.system(size: min(size * 0.15, 22), weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isBigCard ? 12 : size * 0.08)
                .background(Color.blue.opacity(0.8))
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .cornerRadius(isBigCard ? 20 : 12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 🌟🌟🌟 核心修改区域：视频播放遮罩 🌟🌟🌟
    var SuccessVideoOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
            } else {
                VStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.yellow)
                    Text("太棒了！")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
            
            VStack {
                // 🌟 1. 关闭按钮移到左上角，并且使用图标
                HStack {
                    Button(action: {
                        withAnimation { isPlaying = false }
                    }) {
                        Image(systemName: "xmark.circle.fill") // 漂亮的关闭图标
                            .font(.system(size: 44))       // 大一点，好点
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.leading, 20) // 左边距
                    .padding(.top, 20)     // 顶边距
                    
                    Spacer() // 把它顶到左边去
                }
                
                Spacer()
                
                // 2. 底部按钮保持不变
                if currentLevelIndex < levels.count - 1 {
                    Button("下一个故事") {
                        enterLevel(index: currentLevelIndex + 1)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 50)
                } else {
                    Button("完成") {
                        withAnimation { isPlaying = false }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    var ErrorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(debugInfo.isEmpty ? "暂无关卡" : debugInfo)
                .foregroundColor(.black)
                .padding()
            Button("重试") { Task { await loadData() } }
        }
    }
    
    // MARK: - 逻辑
    var currentLevel: SequenceLevel { levels[currentLevelIndex] }
    var isSlotsFull: Bool { !userSlots.contains(where: { $0 == nil }) }
    
    struct Style {
        static let dash = StrokeStyle(lineWidth: 2, dash: [5])
    }
    
    func loadData() async {
        do {
            let fetched = try await NetworkLoader.loadSequencingLevels()
            await MainActor.run {
                self.levels = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.debugInfo = "加载失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func enterLevel(index: Int) {
        setupLevel(index: index)
        withAnimation {
            isPlaying = true
        }
    }
    
    func setupLevel(index: Int) {
        guard index < levels.count else { return }
        currentLevelIndex = index
        let level = levels[index]
        userSlots = Array(repeating: nil, count: level.steps.count)
        availableCards = level.steps.shuffled()
        showSuccessVideo = false
        player = nil
    }
    
    func handleDrop(uuidStr: String, to index: Int) {
        guard let cardIndex = availableCards.firstIndex(where: { $0.id.uuidString == uuidStr }) else { return }
        let card = availableCards[cardIndex]
        withAnimation {
            if let existing = userSlots[index] { availableCards.append(existing) }
            userSlots[index] = card
            availableCards.remove(at: cardIndex)
        }
        speechMgr.speak(english: "", chinese: card.text)
    }
    
    func returnCardToPool(_ card: SequenceStep, at slotIndex: Int) {
        withAnimation {
            userSlots[slotIndex] = nil
            availableCards.append(card)
        }
    }
    
    func checkAnswer() {
            let userOrder = userSlots.compactMap { $0?.image }
            let correctOrder = currentLevel.steps.map { $0.image }
            
            if userOrder == correctOrder {
                speechMgr.speak(english: "Bingo", chinese: "答对了")
                if let videoName = currentLevel.success_video, !videoName.isEmpty {
                    if let videoURL = ResourceLocator.localOrRemoteURL(relativePath: "logic/sequencing/videos/\(videoName)") {
                        self.player = AVPlayer(url: videoURL)
                    }
                }
                withAnimation { showSuccessVideo = true }
            } else {
                speechMgr.speak(english: "Try again", chinese: "再试一次")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        for (idx, slot) in userSlots.enumerated() {
                            if let card = slot {
                                availableCards.append(card)
                                userSlots[idx] = nil
                            }
                        }
                    }
                }
            }
        }
}
