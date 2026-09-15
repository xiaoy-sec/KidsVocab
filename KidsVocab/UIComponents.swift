import SwiftUI

// MARK: - 1. 网络图片加载组件 (带缓存 & 淡入动画)
struct CachedAsyncImage: View {
    let urlString: String
    @State private var uiImage: UIImage? = nil
    @State private var loadTask: Task<Void, Never>? = nil
    
    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .transition(.opacity) // 🌟 淡入效果
            } else {
                Color.gray.opacity(0.1) // 占位背景色
            }
        }
        .onAppear { loadImage() }
        // 🌟 修复：当 URL 变化时（比如点读绘本翻页），图片必须重新加载
        .onChange(of: urlString) { _, _ in loadImage() }
        .onDisappear { loadTask?.cancel() }
        .animation(.easeInOut(duration: 0.3), value: uiImage) // 绑定动画
    }
    
    private func loadImage() {
        loadTask?.cancel()
        guard let url = URL(string: urlString) else {
            uiImage = nil
            return
        }

        let requestedURLString = urlString
        loadTask = Task {
            let image = await Self.loadUIImage(from: url)
            guard !Task.isCancelled, requestedURLString == urlString else { return }
            uiImage = image
        }
    }
    
    private static func loadUIImage(from url: URL) async -> UIImage? {
        if url.isFileURL {
            return await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
        }

        // 1. 优先读缓存
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

// MARK: - 2. 自定义圆角辅助组件
// 允许你只圆左上角、右下角等，而不是必须四个角都圆
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 3. View 扩展方法
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
