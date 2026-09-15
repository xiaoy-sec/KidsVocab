import Foundation
import SwiftUI
import Combine

class AppConfig: ObservableObject {
    static let shared = AppConfig()
    let serverBase: String = "" // 远程请求已禁用，需要时再恢复
}

class NetworkLoader {
    struct LocalCategorySummary {
        let id: String
        let title: String
        let icon: String
        let itemCount: Int
    }
    private struct LocalIndex: Decodable {
        let categories: [LocalCategory]
    }

    private struct LocalCategory: Decodable {
        let id: String
        let title: String
        let icon: String
        let items: [LocalItem]
    }

    private struct LocalItem: Decodable {
        let en: String
        let cn: String
        let image: String
        let audio: String
    }

    private static var cachedIndex: LocalIndex?

    private static func loadLocalIndex() -> LocalIndex? {
        if let cachedIndex = cachedIndex { return cachedIndex }
        guard let url = ResourceLocator.bundleURL(relativePath: "index.json") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoded = try? JSONDecoder().decode(LocalIndex.self, from: data)
        cachedIndex = decoded
        return decoded
    }

    private static let ignoredCategoryIDs: Set<String> = ["KidsVocab", "KidsVocabTests", "KidsVocabUITests", "KidsVocab.xcodeproj", "ogden.json"]

    static func loadLocalIndexForUI() -> [LocalCategorySummary]? {
        guard let index = loadLocalIndex() else { return nil }
        return index.categories
            .filter { !ignoredCategoryIDs.contains($0.id) }
            .map { LocalCategorySummary(id: $0.id, title: $0.title, icon: $0.icon, itemCount: $0.items.count) }
    }

    // 发现分类：排除系统文件夹并支持带空格/连字符的名字
    static func discoverCategories() async -> [String] {
        if let index = loadLocalIndex() {
            return index.categories
                .map { $0.id }
                .filter { !ignoredCategoryIDs.contains($0) }
        }
        // REMOTE DISABLED: previously fetched category list from server root.
        // guard let url = URL(string: AppConfig.shared.serverBase + "/") else { return [] }
        // do {
        //     let (data, _) = try await URLSession.shared.data(from: url)
        //     guard let html = String(data: data, encoding: .utf8) else { return [] }
        //     let pattern = #"href="([a-zA-Z0-9_ ]+)/""#
        //     let regex = try NSRegularExpression(pattern: pattern)
        //     let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        //     let ignored = ["audio", "logic", "conversations", "icons", "body", "cgi-bin"]
        //     return matches.compactMap { match in
        //         guard let range = Range(match.range(at: 1), in: html) else { return nil }
        //         let folder = String(html[range])
        //         return ignored.contains(folder.lowercased()) ? nil : folder
        //     }.sorted()
        // } catch { return [] }
        return []
    }

    // 加载单词：支持百分号解码和下划线切分
    static func loadRemoteItems(folder: String) async -> [LearningItem] {
        if ignoredCategoryIDs.contains(folder) { return [] }
        if let index = loadLocalIndex(),
           let category = index.categories.first(where: { $0.id == folder }) {
            return category.items
                .map { item in
                    let imagePath = item.image
                    let imageUrl = ResourceLocator.localOrRemoteURLString(relativePath: imagePath) ?? ""
                    return LearningItem(name: item.en, chineseName: item.cn, imageUrl: imageUrl)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        // REMOTE DISABLED: previously fetched items from server folder listing.
        // guard let url = URL(string: "\(AppConfig.shared.serverBase)/\(folder)/") else { return [] }
        // do {
        //     let (data, _) = try await URLSession.shared.data(from: url)
        //     guard let html = String(data: data, encoding: .utf8) else { return [] }
        //     let pattern = #"href="([^"]+)\.webp""#
        //     let regex = try NSRegularExpression(pattern: pattern)
        //     let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        //     return matches.compactMap { match in
        //         guard let range = Range(match.range(at: 1), in: html) else { return nil }
        //         let encoded = String(html[range])
        //         guard let full = encoded.removingPercentEncoding, let lastIdx = full.lastIndex(of: "_") else { return nil }
        //         let en = String(full[..<lastIdx]), cn = String(full[full.index(after: lastIdx)...])
        //         return LearningItem(name: en, chineseName: cn, imageUrl: "\(AppConfig.shared.serverBase)/\(folder)/\(encoded).webp")
        //     }
        // } catch { return [] }
        return []
    }

    // 发现对话
    static func discoverConversationFolders() async -> [String] {
        if let local = loadLocalConversationFolders(), !local.isEmpty {
            return sortLessonFolders(local)
        }
        // REMOTE DISABLED: previously fetched conversation list from server.
        // guard let url = URL(string: "\(AppConfig.shared.serverBase)/conversations/") else { return [] }
        // do {
        //     let (data, _) = try await URLSession.shared.data(from: url)
        //     guard let html = String(data: data, encoding: .utf8) else { return [] }
        //     let pattern = #"href="([^"/]+)/""#
        //     let regex = try NSRegularExpression(pattern: pattern)
        //     let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        //     return matches.compactMap { match in
        //         guard let range = Range(match.range(at: 1), in: html) else { return nil }
        //         let f = String(html[range])
        //         return (!f.hasPrefix(".") && f != "icons") ? f : nil
        //     }.sorted()
        // } catch { return [] }
        return []
    }

    private static func loadLocalConversationFolders() -> [String]? {
        let subdirectories = ["Resources/conversations", "conversations"]
        for subdir in subdirectories {
            if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: subdir) {
                let folders = urls
                    .filter { $0.lastPathComponent == "script.json" }
                    .compactMap { $0.deletingLastPathComponent().lastPathComponent }
                if !folders.isEmpty { return sortLessonFolders(folders) }
            }
        }
        guard let base = Bundle.main.resourceURL else { return nil }
        for subdir in subdirectories {
            let dirUrl = base.appendingPathComponent(subdir)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dirUrl.path, isDirectory: &isDir), isDir.boolValue {
                let folders = conversationFolders(in: dirUrl)
                if !folders.isEmpty { return sortLessonFolders(folders) }
            }
        }
        return nil
    }

    private static func conversationFolders(in directory: URL) -> [String] {
        guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var result: [String] = []
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let scriptUrl = child.appendingPathComponent("script.json")
            if FileManager.default.fileExists(atPath: scriptUrl.path) {
                result.append(child.lastPathComponent)
            }
        }
        return result
    }

    private static func sortLessonFolders(_ folders: [String]) -> [String] {
        folders.sorted { lhs, rhs in
            let lNum = lessonNumber(from: lhs)
            let rNum = lessonNumber(from: rhs)
            if lNum != rNum { return lNum < rNum }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private static func lessonNumber(from folder: String) -> Int {
        let digits = folder.filter { $0.isNumber }
        return Int(digits) ?? Int.max
    }

    // 逻辑游戏加载
    static func loadOddOneOutLevels() async throws -> [LogicLevel] { try await fetchJSON("logic/classification/odd_one_out/config.json") }
    static func loadSequencingLevels() async throws -> [SequenceLevel] { try await fetchJSON("logic/sequencing/config.json") }
    static func loadCauseEffectLevels() async throws -> [CauseEffectLevel] { try await fetchJSON("logic/cause_effect/config.json") }
    static func loadMatrixLevels() async throws -> [MatrixLevel] { try await fetchJSON("logic/matrix/config.json") }
    static func loadRavenLevels() async throws -> [RavenLevel] { try await fetchJSON("logic/raven/config.json") }

    private static func fetchJSON<T: Decodable>(_ path: String) async throws -> [T] {
        if let localUrl = ResourceLocator.bundleURL(relativePath: path) {
            let data = try Data(contentsOf: localUrl)
            return try JSONDecoder().decode([T].self, from: data)
        }
        // REMOTE DISABLED: previously fetched JSON from server.
        // guard let url = URL(string: "\(AppConfig.shared.serverBase)/\(path)") else { throw URLError(.badURL) }
        // var request = URLRequest(url: url)
        // request.cachePolicy = .reloadIgnoringLocalCacheData
        // let (data, response) = try await URLSession.shared.data(for: request)
        // if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 { throw URLError(.badServerResponse) }
        // return try JSONDecoder().decode([T].self, from: data)
        throw URLError(.resourceUnavailable)
    }
}
