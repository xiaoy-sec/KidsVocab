import SwiftUI

struct DialogueStageView: View {
    let lesson: ConversationLesson
    
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @ObservedObject var speechMgr = SpeechManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack(alignment: .top) {
                if isLandscape {
                    // === 横屏布局 ===
                    HStack(spacing: 0) {
                        // 左侧图片
                        ZStack {
                            Color.black
                            imageContent
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width * 0.55, height: geometry.size.height)
                                .blur(radius: 20).opacity(0.3)
                            imageContent
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width * 0.55)
                                .clipped()
                        }
                        .frame(width: geometry.size.width * 0.55)
                        .ignoresSafeArea()
                        
                        // 右侧交互
                        VStack(spacing: 0) {
                            // 导航栏
                            HStack {
                                backButton
                                Spacer()
                                titlePill
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 15) // 顶部留一点点缝隙
                            .padding(.bottom, 5) // 紧接着就是列表
                            
                            Divider().opacity(0.3)
                            
                            // 列表区
                            scriptListArea
                            
                            // 底部控制
                            bottomControlBar
                        }
                        .frame(width: geometry.size.width * 0.45)
                        .background(Color(.systemBackground))
                    }
                } else {
                    // === 竖屏布局 ===
                    VStack(spacing: 0) {
                        imageContent
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.45)
                            .clipped()
                            .background(Color.black)
                        
                        VStack(spacing: 0) {
                            scriptListArea
                            bottomControlBar
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(30, corners: [.topLeft, .topRight])
                        .offset(y: -80)
                        .padding(.bottom, -80)
                    }
                    
                    HStack {
                        backButton
                        Spacer()
                        titlePill
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                }
            }
            .ignoresSafeArea(edges: isLandscape ? [] : .top)
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Components
    
    private var imageContent: some View {
        let relativePath = "conversations/\(lesson.folderName)/\(lesson.backgroundImage).webp"
        let bgURL = ResourceLocator.localOrRemoteURLString(relativePath: relativePath) ?? ""
        return CachedAsyncImage(urlString: bgURL)
    }
    
    private var backButton: some View {
        Button(action: { speechMgr.stop(); dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 3)
        }
    }
    
    private var titlePill: some View {
        Text(lesson.title)
            .font(.system(.caption, design: .rounded).bold())
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 3)
    }
    
    private var scriptListArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // 🌟 使用 VStack 替代 LazyVStack，并且去掉顶部的 Spacer，强制内容靠上
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<lesson.script.count, id: \.self) { index in
                        let line = lesson.script[index]
                        let isCurrent = currentStep == index
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(line.textEN)
                                .font(.system(size: 24, weight: isCurrent ? .heavy : .medium, design: .rounded))
                                .foregroundColor(isCurrent ? .blue : .primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                            
                            Text(line.textCN)
                                .font(.system(size: 18))
                                .foregroundColor(isCurrent ? .blue : .secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isCurrent ? Color.blue.opacity(0.05) : Color.clear)
                        .contentShape(Rectangle())
                        .id(index)
                        .onTapGesture {
                            currentStep = index
                            playCurrentLine()
                        }
                        
                        Divider().padding(.leading, 24)
                    }
                }
                .padding(.bottom, 20)
            }
            .onChange(of: currentStep) { _, newStep in
                // 🌟 滚动时让当前句尽量靠上，而不是居中，这样视野更好
                withAnimation { proxy.scrollTo(newStep, anchor: .top) }
            }
        }
    }
    
    private var bottomControlBar: some View {
        HStack(spacing: 50) {
            Button(action: { if currentStep > 0 { currentStep -= 1; playCurrentLine() } }) {
                Image(systemName: "backward.fill").font(.title2)
            }
            
            Button(action: { playCurrentLine() }) {
                Image(systemName: speechMgr.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color(.systemBackground)))
                    .shadow(color: .blue.opacity(0.2), radius: 8, y: 4)
            }
            
            Button(action: { if currentStep < lesson.script.count - 1 { currentStep += 1; playCurrentLine() } }) {
                Image(systemName: "forward.fill").font(.title2)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: -5)
    }

    func playCurrentLine() {
        let line = lesson.script[currentStep]
        speechMgr.speak(english: line.textEN, chinese: line.textCN)
    }
}
