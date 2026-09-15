import SwiftUI

struct LogicHomeView: View {
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("逻辑思维训练")
                        .font(.largeTitle.bold())
                        .padding(.horizontal)
                        .padding(.top)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        // 1. 找不同
                        NavigationLink(destination: OddOneOutGameView()) {
                            ModuleCard(title: "找不同", icon: "square.grid.2x2.fill", color: .orange)
                        }
                        
                        // 2. 顺序流程
                        NavigationLink(destination: SequencingGameView()) {
                            ModuleCard(title: "顺序流程", icon: "arrow.triangle.swap", color: .blue)
                        }
                        
                        // 3. 因果推理
                        NavigationLink(destination: CauseEffectGameView()) {
                            ModuleCard(title: "因果推理", icon: "lightbulb.fill", color: .purple)
                        }

                        // 4. 矩阵推理
                        NavigationLink(destination: MatrixGameView()) {
                            ModuleCard(title: "矩阵推理", icon: "grid", color: .teal)
                        }
                        
                        // 5. 瑞文测试
                        NavigationLink(destination: RavenTestGameView()) {
                            ModuleCard(title: "瑞文测试", icon: "brain.head.profile", color: .indigo)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    func ModuleCard(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(color.gradient)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}
