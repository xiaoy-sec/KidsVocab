import SwiftUI

// 🌟 定义一个简单的结构体，代表日历上的一个小格子
struct CalendarDayItem: Identifiable {
    let id = UUID()
    let date: Date?    // 如果是 nil，说明是空白格
    let dayNumber: Int // 显示的数字
}

private struct HistorySelection: Identifiable {
    let id = UUID()
    let dateStr: String
    let wordIDs: [String]
}

struct CalendarView: View {
    @ObservedObject var historyMgr = HistoryManager.shared
    
    // 当前显示的月份 (初始化为当月1号)
    @State private var currentMonth: Date = {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    // 弹窗状态
    @State private var selectedHistory: HistorySelection? = nil
    
    // 固定使用公历，确保计算逻辑统一 (1=周日, 2=周一 ... 7=周六)
    private let calendar = Calendar(identifier: .gregorian)
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    // 强制表头：周日排第一列
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        VStack(spacing: 15) {
            // === 1. 标题栏 ===
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3).padding(10)
                        .contentShape(Rectangle())
                }
                
                Spacer()
                
                Text(monthYearString(currentMonth))
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3).padding(10)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 5)
            
            // 统计小标签
            HStack(spacing: 4) {
                Spacer()
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Text("本月已打卡 \(completedDaysCount()) 天")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.bottom, 5)
            
            // === 2. 星期表头 ===
            LazyVGrid(columns: columns) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day).font(.subheadline.bold()).foregroundColor(.secondary)
                }
            }
            
            // === 3. 日期网格 (核心修复) ===
            // 直接遍历计算好的数组，不再用 offset 逻辑
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(generateCalendarGrid(), id: \.id) { item in
                    if let date = item.date {
                        // 真实日期
                        dayCell(day: item.dayNumber, date: date)
                            .onTapGesture {
                                handleDateTap(date: date)
                            }
                    } else {
                        // 空白占位格
                        Text("")
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground)) // 灰色背景
        .cornerRadius(20)
        // 滑动手势
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.width > 50 { withAnimation { changeMonth(by: -1) } }
                else if value.translation.width < -50 { withAnimation { changeMonth(by: 1) } }
            }
        )
        // 弹窗
        .sheet(item: $selectedHistory) { selection in
            HistoryDetailView(dateStr: selection.dateStr, wordIDs: selection.wordIDs)
        }
    }
    // MARK: 生成完整的网格数据 test
    private func generateCalendarGrid() -> [CalendarDayItem] {
        var days: [CalendarDayItem] = []
        
        // 1. 获取当月第一天
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let firstDayOfMonth = calendar.date(from: components)!
        
        // 2. 算出当月有多少天
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
        let numDays = range.count
        
        // 3. 算出第一天是周几 (1=周日, 2=周一 ... 7=周六)
        // 无论系统怎么设置，Gregorian 日历里 Sunday 永远是 1
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // 4. 计算前面需要空几个格子
        // 因为我们的表头是 ["日", "一"...]，所以：
        // 如果是周日(1)，空 0 格 (1-1)
        // 如果是周一(2)，空 1 格 (2-1)
        // 如果是周四(5)，空 4 格 (5-1)
        let offset = firstWeekday - 1
        
        // 5. 填充前面的空白格
        for _ in 0..<offset {
            days.append(CalendarDayItem(date: nil, dayNumber: 0))
        }
        
        // 6. 填充真实的日期
        for i in 1...numDays {
            // 算出这一天的真实 Date
            if let date = calendar.date(byAdding: .day, value: i - 1, to: firstDayOfMonth) {
                days.append(CalendarDayItem(date: date, dayNumber: i))
            }
        }
        
        return days
    }
    
    // MARK: - 其他逻辑保持不变
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            // 强制重置为1号
            let components = calendar.dateComponents([.year, .month], from: newDate)
            currentMonth = calendar.date(from: components) ?? newDate
        }
    }
    
    private func handleDateTap(date: Date) {
        if let record = historyMgr.getRecord(for: date), !record.learnedWords.isEmpty {
            self.selectedHistory = HistorySelection(dateStr: record.dateString, wordIDs: record.learnedWords)
        }
    }
    
    private func dayCell(day: Int, date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let record = historyMgr.getRecord(for: date)
        let isCompleted = record?.isCompleted ?? false
        let hasData = record != nil && !(record?.learnedWords.isEmpty ?? true)
        
        return ZStack {
            if isCompleted {
                Circle().fill(Color.yellow)
                    .shadow(color: .orange.opacity(0.3), radius: 2, y: 2)
            } else if isToday {
                Circle().stroke(Color.blue, lineWidth: 2)
            } else if hasData {
                Circle().fill(Color.gray.opacity(0.2))
            }
            
            Text("\(day)")
                .font(.system(size: 16, weight: isToday || isCompleted ? .bold : .medium))
                .foregroundColor(isCompleted ? .black : .primary)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: date)
    }
    
    private func completedDaysCount() -> Int {
        return historyMgr.history.filter {
            let recordDate = stringToDate($0.dateString)
            // 比较月份是否相同
            return calendar.isDate(recordDate, equalTo: currentMonth, toGranularity: .month) && $0.isCompleted
        }.count
    }
    
    private func stringToDate(_ str: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str) ?? Date()
    }
}
