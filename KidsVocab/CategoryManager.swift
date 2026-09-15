import Foundation
import SwiftUI
import Combine

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    @Published var categories: [Category] = []
    @Published var isLoading = false
    
    func refreshCategories() async {
        await MainActor.run { self.isLoading = true }
        let folders = await NetworkLoader.discoverCategories()
        var temp: [Category] = []

        if let index = NetworkLoader.loadLocalIndexForUI() {
            temp = index.map {
                let iconPath = resolveIconPath($0.icon)
                return Category(title: $0.title, iconPath: iconPath, folderName: $0.id, itemCount: $0.itemCount)
            }
        } else {
            for folder in folders {
                let suffix = await fetchInfoAsync(folder: folder)
                temp.append(Category(title: "\(folder.capitalized) \(suffix)", iconPath: "\(folder)_icon.webp", folderName: folder))
            }
        }
        
        // 🌟 核心优化：Body 模块独立，不进入网络并发池
        temp.insert(Category(title: "Body 人体", iconPath: "body_icon.webp", folderName: "body", itemCount: GlobalMarioParts.count), at: 0)
        
        await withTaskGroup(of: (Int, Int).self) { group in
            for (idx, cat) in temp.enumerated() where cat.folderName != "body" {
                if cat.itemCount == 0 {
                    group.addTask { (idx, await NetworkLoader.loadRemoteItems(folder: cat.folderName).count) }
                }
            }
            for await (idx, count) in group { temp[idx].itemCount = count }
        }
        
        await MainActor.run {
            self.categories = temp
            self.isLoading = false
        }
    }

    private func fetchInfoAsync(folder: String) async -> String {
        // REMOTE DISABLED: previously fetched info.txt from server.
        // guard let url = URL(string: "\(AppConfig.shared.serverBase)/\(folder)/info.txt") else { return "" }
        // do {
        //     let (data, res) = try await URLSession.shared.data(from: url)
        //     return (res as? HTTPURLResponse)?.statusCode == 200 ? String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" : ""
        // } catch { return "" }
        return ""
    }

    private func resolveIconPath(_ icon: String) -> String {
        if ResourceLocator.bundleURL(relativePath: icon) != nil { return icon }
        let fallback = "icons/\(icon)"
        if ResourceLocator.bundleURL(relativePath: fallback) != nil { return fallback }
        return icon
    }
}
