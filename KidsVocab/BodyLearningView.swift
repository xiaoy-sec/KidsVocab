import SwiftUI

struct BodyLearningView: View {
    let category: Category
    
    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let imageAspect: CGFloat = 800.0 / 1280.0
            let containerAspect = containerSize.width / max(containerSize.height, 1)
            let scaleByHeight = containerAspect > imageAspect

            let imageHeight: CGFloat = scaleByHeight ? containerSize.height : (containerSize.width / imageAspect)
            let imageWidth: CGFloat = scaleByHeight ? (imageHeight * imageAspect) : containerSize.width
            let xOffset: CGFloat = scaleByHeight ? (containerSize.width - imageWidth) / 2 : 0
            let yOffset: CGFloat = scaleByHeight ? 0 : (containerSize.height - imageHeight) / 2

            // 🌟 重新规划两侧标签的固定展示宽度（可根据实际效果微调）
            let sideWidth: CGFloat = 85

            ZStack {
                // 1. 底图
                Image("body")
                    .resizable()
                    .scaledToFit()
                    .frame(width: containerSize.width, height: containerSize.height)
                
                // 2. 🌟 绘制引线层（带有拐角和中心原点，充满科技感）
                Canvas { context, size in
                    for part in GlobalMarioParts {
                        // 计算目标器官在屏幕上的绝对物理坐标
                        let targetX = xOffset + imageWidth * part.x
                        let targetY = yOffset + imageHeight * part.y
                        
                        // 计算两侧标签在屏幕上的基准起始物理坐标
                        let labelX = part.isLeft ? sideWidth : (containerSize.width - sideWidth)
                        let labelY = targetY // 让引线水平拉出，视觉最规整
                        
                        // 拐点坐标（让线先水平走一段，再斜着指向器官）
                        let inflectionX = part.isLeft ? (labelX + 20) : (labelX - 20)
                        
                        // 绘制折线
                        var path = Path()
                        path.move(to: CGPoint(x: labelX, y: labelY))
                        path.addLine(to: CGPoint(x: inflectionX, y: labelY))
                        path.addLine(to: CGPoint(x: targetX, y: targetY))
                        
                        context.stroke(path, with: .color(.blue.opacity(0.4)), lineWidth: 1.5)
                        
                        // 在器官中心点画一个小实心圆，表示精准指向
                        let dotRect = CGRect(x: targetX - 3, y: targetY - 3, width: 6, height: 6)
                        context.fill(Path(ellipseIn: dotRect), with: .color(.blue.opacity(0.7)))
                    }
                }
                .allowsHitTesting(false) // 允许点击穿透线条层
                
                // 3. 遍历生成按钮（左侧排成一列，右侧排成一列）
                ForEach(GlobalMarioParts) { part in
                    Button(action: {
                        SpeechManager.shared.speak(english: part.name, chinese: part.chineseName)
                    }) {
                        HStack(spacing: 4) {
                            if part.isLeft {
                                Text(part.name)
                                    .font(.system(.caption, design: .rounded).bold())
                                    .padding(4)
                                    .background(Capsule().fill(Color.black.opacity(0.6)))
                                    .foregroundColor(.white)
                                Circle().strokeBorder(Color.white, lineWidth: 2)
                                    .background(Circle().fill(Color.blue.opacity(0.5)))
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle().strokeBorder(Color.white, lineWidth: 2)
                                    .background(Circle().fill(Color.blue.opacity(0.5)))
                                    .frame(width: 24, height: 24)
                                Text(part.name)
                                    .font(.system(.caption, design: .rounded).bold())
                                    .padding(4)
                                    .background(Capsule().fill(Color.black.opacity(0.6)))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    // 根据是在左边还是右边，精确定位按钮
                    .position(
                        x: part.isLeft ? (sideWidth - 35) : (containerSize.width - sideWidth + 35),
                        y: yOffset + imageHeight * part.y
                    )
                }
            }
            // 🌟 临时坐标抓取逻辑 (保持原样，后续若需要改动直接用)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let relativeX = location.x - xOffset
                let relativeY = location.y - yOffset
                let percentX = relativeX / imageWidth
                let percentY = relativeY / imageHeight
                if (0...1).contains(percentX) && (0...1).contains(percentY) {
                    let strX = String(format: "%.3f", percentX)
                    let strY = String(format: "%.3f", percentY)
                    print("📍 新坐标 -> x: \(strX), y: \(strY)")
                }
            }
        }
        .navigationTitle(category.title)
        .background(Color.white)
    }
}
