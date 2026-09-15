import Foundation
import SwiftUI
import Combine

final class MasteryManager: ObservableObject {
    static let shared = MasteryManager()
    @Published private(set) var storage: [String: String] = [:] { didSet { save() } }
    private let saveKey = "KidsVocab_Mastery_Storage"
    private let batchKey = "KidsVocab_Study_Batch_Starts"
    private let studyPhaseKey = "KidsVocab_Study_Phases"

    private init() { load() }

    func getStatus(for word: OgdenWord, deckID: String) -> MasteryStatus {
        if let saved = storage[wordKey(for: word, deckID: deckID)], let status = MasteryStatus(rawValue: saved) {
            return status
        }
        // Preserve existing progress from the former single Ogden deck.
        if deckID == "ogden.json", let saved = storage["\(word.w)_\(word.zh)"], let status = MasteryStatus(rawValue: saved) {
            return status
        }
        return .none
    }

    func setStatus(_ status: MasteryStatus, for word: OgdenWord, deckID: String) {
        storage[wordKey(for: word, deckID: deckID)] = status.rawValue
    }

    func currentBatchStart(for deckID: String, wordCount: Int) -> Int {
        guard wordCount > 0 else { return 0 }
        let starts = UserDefaults.standard.dictionary(forKey: batchKey) as? [String: Int] ?? [:]
        return min(max(starts[deckID] ?? 0, 0), ((wordCount - 1) / 10) * 10)
    }

    func studyPhase(for deckID: String) -> StudyPhase {
        let phases = UserDefaults.standard.dictionary(forKey: studyPhaseKey) as? [String: String] ?? [:]
        return StudyPhase(rawValue: phases[deckID] ?? "") ?? .learning
    }

    func completeCurrentBatch(for deckID: String) {
        setStudyPhase(.readyToReview, for: deckID)
    }

    func startReview(for deckID: String) {
        setStudyPhase(.reviewing, for: deckID)
    }

    func finishReview(for deckID: String, wordCount: Int) {
        let current = currentBatchStart(for: deckID, wordCount: wordCount)
        if current + 10 < wordCount {
            var starts = UserDefaults.standard.dictionary(forKey: batchKey) as? [String: Int] ?? [:]
            starts[deckID] = current + 10
            UserDefaults.standard.set(starts, forKey: batchKey)
            setStudyPhase(.learning, for: deckID)
        } else {
            setStudyPhase(.finished, for: deckID)
        }
    }

    private func wordKey(for word: OgdenWord, deckID: String) -> String { "\(deckID)::\(word.w)_\(word.zh)" }
    private func setStudyPhase(_ phase: StudyPhase, for deckID: String) {
        var phases = UserDefaults.standard.dictionary(forKey: studyPhaseKey) as? [String: String] ?? [:]
        phases[deckID] = phase.rawValue
        UserDefaults.standard.set(phases, forKey: studyPhaseKey)
        objectWillChange.send()
    }
    private func save() {
        if let encoded = try? JSONEncoder().encode(storage) { UserDefaults.standard.set(encoded, forKey: saveKey) }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey), let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            storage = decoded
        }
    }
}

enum MasteryStatus: String, CaseIterable {
    case none, mastered, familiar, unknown
    var color: Color {
        switch self {
        case .none, .unknown: .red
        case .mastered: .green
        case .familiar: .orange
        }
    }
}

struct WordDeck: Identifiable {
    let fileName: String
    let words: [OgdenWord]
    var id: String { fileName }
    var title: String { (fileName as NSString).deletingPathExtension }
}

private enum WordDeckLoader {
    static func loadDecks() throws -> [WordDeck] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "allwords") ?? []
        return try urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }.map { url in
            WordDeck(fileName: url.lastPathComponent, words: try JSONDecoder().decode([OgdenWord].self, from: Data(contentsOf: url)))
        }
    }
}

private enum VocabularyDisplayMode: String, CaseIterable { case all = "全部", study = "学习" }

enum StudyPhase: String {
    case learning
    case readyToReview
    case reviewing
    case finished
}

struct OgdenWordCard: View {
    let word: OgdenWord
    let deckID: String
    @ObservedObject var manager: MasteryManager
    @State private var showingStatusPicker = false
    private var currentStatus: MasteryStatus { manager.getStatus(for: word, deckID: deckID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button(action: speakWord) {
                    Text(word.w).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 8)
                Button { showingStatusPicker = true } label: {
                    Circle().fill(currentStatus.color).frame(width: 30, height: 30).overlay {
                        Image(systemName: currentStatus == .mastered ? "checkmark" : "ellipsis").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("设置 \(word.w) 的掌握程度")
            }
            Text(word.zh).font(.system(size: 18, weight: .medium)).foregroundStyle(.blue)
            Divider()
            Text("例句").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Button(action: speakExample) {
                Text(word.ex).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Text(word.exz).font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .secondarySystemGroupedBackground)).shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .confirmationDialog("选择掌握程度", isPresented: $showingStatusPicker) {
            Button("已掌握") { manager.setStatus(.mastered, for: word, deckID: deckID) }
            Button("不熟练") { manager.setStatus(.familiar, for: word, deckID: deckID) }
            Button("未掌握") { manager.setStatus(.unknown, for: word, deckID: deckID) }
            Button("取消", role: .cancel) {}
        }
    }

    private func speakWord() { SpeechManager.shared.speakVocabularyWord(english: word.w, chinese: word.zh) }
    private func speakExample() { SpeechManager.shared.speakVocabularyWord(english: word.ex, chinese: "") }
}

struct OgdenVocabView: View {
    @StateObject private var manager = MasteryManager.shared
    @State private var decks: [WordDeck] = []
    @State private var selectedDeckID: String?
    @State private var displayMode: VocabularyDisplayMode = .all
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingSidebar = true
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var selectedDeck: WordDeck? { decks.first { $0.id == selectedDeckID } }
    private var visibleWords: [OgdenWord] {
        guard let deck = selectedDeck else { return [] }
        guard !searchText.isEmpty else { return deck.words }
        return deck.words.filter { $0.w.localizedCaseInsensitiveContains(searchText) || $0.zh.localizedCaseInsensitiveContains(searchText) || $0.ex.localizedCaseInsensitiveContains(searchText) || $0.exz.localizedCaseInsensitiveContains(searchText) }
    }
    private var studyWords: [OgdenWord] {
        guard let deck = selectedDeck else { return [] }
        let start = manager.currentBatchStart(for: deck.id, wordCount: deck.words.count)
        return Array(deck.words.dropFirst(start).prefix(10))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                mainContent
                if showingSidebar { deckSidebar.transition(.move(edge: .leading).combined(with: .opacity)).zIndex(1) }
            }
            .animation(.easeInOut(duration: 0.2), value: showingSidebar)
            .navigationTitle(selectedDeck?.title ?? "基础单词")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSidebar.toggle() } label: { Image(systemName: "sidebar.left") }
                        .accessibilityLabel(showingSidebar ? "收起牌组侧边栏" : "打开牌组侧边栏")
                }
            }
            .task { loadDecks() }
        }
    }

    @ViewBuilder private var mainContent: some View {
        if isLoading {
            ProgressView("正在加载词库…")
        } else if let errorMessage {
            ContentUnavailableView("词库加载失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
        } else if selectedDeck == nil {
            ContentUnavailableView("还没有词库", systemImage: "books.vertical", description: Text("请将同格式的 JSON 文件放入 allwords 文件夹。"))
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    deckPickerButton
                    deckSummary
                    modeSelector
                    if displayMode == .all {
                        SearchBar(text: $searchText)
                        wordGrid(words: visibleWords)
                    } else {
                        studyContent
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var deckSummary: some View {
        HStack(spacing: 8) {
            summaryItem("总数", count: selectedDeck?.words.count ?? 0, color: .primary)
            summaryItem("未掌握", count: unmasteredCount(in: selectedDeck), color: .red)
            summaryItem("不熟练", count: count(of: .familiar, in: selectedDeck), color: .orange)
            summaryItem("掌握", count: count(of: .mastered, in: selectedDeck), color: .green)
        }
        .padding(.horizontal, 12)
    }

    private var deckPickerButton: some View {
        Button { showingSidebar = true } label: {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                Text("选择牌组")
                    .fontWeight(.semibold)
                Text(selectedDeck?.title ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    private var modeSelector: some View {
        HStack(spacing: 10) {
            modeButton(.all, icon: "list.bullet", subtitle: "浏览全部单词")
            modeButton(.study, icon: "graduationcap.fill", subtitle: "每天学习 10 个")
        }
        .padding(.horizontal, 12)
    }

    private func modeButton(_ mode: VocabularyDisplayMode, icon: String, subtitle: String) -> some View {
        Button { displayMode = mode } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label(mode.rawValue, systemImage: icon)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
            }
            .foregroundStyle(displayMode == mode ? .white : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(displayMode == mode ? Color.green : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func summaryItem(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 3) { Text("\(count)").font(.headline).foregroundStyle(color); Text(label).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var studyContent: some View {
        if let deck = selectedDeck {
            let start = manager.currentBatchStart(for: deck.id, wordCount: deck.words.count)
            switch manager.studyPhase(for: deck.id) {
            case .learning:
                Text("学习第 \(start + 1)–\(min(start + studyWords.count, deck.words.count)) 个单词").font(.subheadline).foregroundStyle(.secondary)
                wordGrid(words: studyWords)
                Button { manager.completeCurrentBatch(for: deck.id) } label: {
                    Label("已完成当前组", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.green).padding(.horizontal, 12)
            case .readyToReview:
                reviewPrompt(title: "本组学习已完成", detail: "先复习刚学过的 10 个单词，再进入下一组。", buttonTitle: "复习上一组", deckID: deck.id)
            case .reviewing:
                Text("复习第 \(start + 1)–\(min(start + studyWords.count, deck.words.count)) 个单词").font(.subheadline).foregroundStyle(.secondary)
                wordGrid(words: studyWords)
                Button { manager.finishReview(for: deck.id, wordCount: deck.words.count) } label: {
                    Label(start + 10 < deck.words.count ? "复习完成，继续学习" : "复习完成", systemImage: "arrow.right.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.green).padding(.horizontal, 12)
            case .finished:
                reviewPrompt(title: "已完成全部学习", detail: "你可以随时复习最后学习的 10 个单词。", buttonTitle: "复习最后一组", deckID: deck.id)
            }
        }
    }

    private func reviewPrompt(title: String, detail: String, buttonTitle: String, deckID: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill").font(.system(size: 46)).foregroundStyle(.green)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { manager.startReview(for: deckID) } label: {
                Label(buttonTitle, systemImage: "arrow.counterclockwise.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.green)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
    }

    @ViewBuilder private func wordGrid(words: [OgdenWord]) -> some View {
        if words.isEmpty {
            ContentUnavailableView("没有匹配的单词", systemImage: "magnifyingglass").padding(.top, 60)
        } else if let deck = selectedDeck {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(words) { OgdenWordCard(word: $0, deckID: deck.id, manager: manager) }
            }
            .padding(.horizontal, 12)
        }
    }

    private var deckSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("我的牌组", systemImage: "rectangle.stack.fill").font(.headline)
                Spacer()
                Button { showingSidebar = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            .padding()
            Divider()
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(decks) { deck in
                        Button {
                            selectedDeckID = deck.id
                            searchText = ""
                            showingSidebar = false
                        } label: { deckRow(deck) }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 292)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.22), radius: 12, x: 4)
    }

    private func deckRow(_ deck: WordDeck) -> some View {
        let learned = deck.words.filter { manager.getStatus(for: $0, deckID: deck.id) != .none }.count
        let progress = deck.words.isEmpty ? 0 : Int((Double(learned) / Double(deck.words.count) * 100).rounded())
        return VStack(alignment: .leading, spacing: 7) {
            HStack { Text(deck.title).font(.headline).lineLimit(1); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
            Text("\(deck.words.count) 词  \(progress)%").font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(learned), total: Double(max(deck.words.count, 1))).tint(.green)
        }
        .padding(12)
        .background(selectedDeckID == deck.id ? Color.green.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func count(of status: MasteryStatus, in deck: WordDeck?) -> Int {
        guard let deck else { return 0 }
        return deck.words.filter { manager.getStatus(for: $0, deckID: deck.id) == status }.count
    }
    private func unmasteredCount(in deck: WordDeck?) -> Int {
        guard let deck else { return 0 }
        return deck.words.filter {
            let status = manager.getStatus(for: $0, deckID: deck.id)
            return status == .none || status == .unknown
        }.count
    }
    private func loadDecks() {
        do {
            decks = try WordDeckLoader.loadDecks()
            selectedDeckID = selectedDeckID ?? decks.first?.id
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索单词、中文或例句…", text: $text).textFieldStyle(.plain)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }
}

#Preview { OgdenVocabView() }
