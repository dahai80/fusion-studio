// Callers: ProfilerView, TaskQueueView
// Affected API: FusionProgressRing view
// Data schemas: FusionProgressRing (value: Double, lineWidth: CGFloat, showLabel: Bool, size: CGFloat)
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI
import os.log

private let fusionProgressRingLog = os.Logger(subsystem: "com.fusion.studio", category: "FusionProgressRing")

struct FusionProgressRing: View {
    let value: Double
    let lineWidth: CGFloat
    let showLabel: Bool
    let size: CGFloat

    @Environment(\.studioTheme) var theme
    @State private var animatedValue: Double = 0

    init(value: Double, lineWidth: CGFloat = 4, showLabel: Bool = true, size: CGFloat = 44) {
        self.value = value
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.size = size
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = (min(canvasSize.width, canvasSize.height) - lineWidth) / 2

                let trackPath = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                context.stroke(trackPath, with: .color(theme.controlBg), lineWidth: lineWidth)

                let clampedValue = min(max(animatedValue, 0), 1)
                if clampedValue > 0.001 {
                    let endAngle = 360.0 * clampedValue
                    let fillPath = Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + endAngle),
                            clockwise: false
                        )
                    }

                    let startAngleRad = Angle.degrees(-90).radians
                    let endAngleRad = Angle.degrees(-90 + endAngle).radians
                    let startPoint = CGPoint(
                        x: center.x + radius * cos(startAngleRad),
                        y: center.y + radius * sin(startAngleRad)
                    )
                    let endPoint = CGPoint(
                        x: center.x + radius * cos(endAngleRad),
                        y: center.y + radius * sin(endAngleRad)
                    )

                    var fillStroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    context.stroke(
                        fillPath,
                        with: .linearGradient(
                            Gradient(colors: [theme.accent, theme.accentSecondary]),
                            startPoint: startPoint,
                            endPoint: endPoint
                        ),
                        style: fillStroke
                    )
                }
            }
            .frame(width: size, height: size)
            .overlay {
                if showLabel {
                    Text("\(Int(animatedValue * 100))%")
                        .font(.system(size: theme.captionSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text)
                }
            }
        }
        .onAppear {
            fusionProgressRingLog.info("FusionProgressRing appeared, target value: \(self.value)")
            withAnimation(theme.springDefault) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            fusionProgressRingLog.info("FusionProgressRing value changed to \(newValue)")
            withAnimation(theme.springDefault) {
                animatedValue = newValue
            }
        }
    }
}
