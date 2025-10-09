import SwiftUI

// MARK: - Skeleton 骨架屏组件

struct SkeletonUserCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.secondary.opacity(0.20))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 180, height: 12)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .redacted(reason: .placeholder)
        .shimmer(duration: 0.65, bounce: true, angle: 0, intensity: 0.60, bandScale: 1.70)
    }
}

struct SkeletonChartBlock: View {
    let height: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.18))
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .redacted(reason: .placeholder)
            .shimmer()
    }
}

struct SkeletonStatsRow: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 20)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 10)
            }
            Spacer()
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 20)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 10)
            }
            Spacer()
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 20)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 10)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
        .shimmer()
    }
}

// MARK: - Shimmer 闪动效果（水平左→右，更明显）
private struct ShimmerModifier: ViewModifier {
    var duration: Double = 0.70       // 速度：越小越快（更快）
    var bounce: Bool = true           // 是否来回扫（开启更显眼）
    var angle: Double = 0             // 水平扫光（0 度）
    var intensity: Double = 0.60      // 亮度峰值更高
    var bandScale: CGFloat = 1.65     // 扫光带更宽
    var blendMode: BlendMode = .screen// 叠加更亮

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let size = geo.size
                    let highlight = Color.white
                    let gradient = LinearGradient(
                        colors: [highlight.opacity(0.0),
                                 highlight.opacity(intensity),
                                 highlight.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    let bandW = max(size.width, size.height) * bandScale
                    let bandH = bandW * 3

                    Rectangle()
                        .fill(gradient)
                        .frame(width: bandW, height: bandH)
                        .rotationEffect(.degrees(angle))     // 0° = 纯水平
                        .offset(x: phase * (size.width + bandW))
                        .blendMode(blendMode)
                        .compositingGroup()
                        .allowsHitTesting(false)
                }
                .mask(content)
            )
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: bounce)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(
        duration: Double = 0.70,
        bounce: Bool = true,
        angle: Double = 0,
        intensity: Double = 0.60,
        bandScale: CGFloat = 1.65,
        blendMode: BlendMode = .screen
    ) -> some View {
        modifier(ShimmerModifier(
            duration: duration,
            bounce: bounce,
            angle: angle,
            intensity: intensity,
            bandScale: bandScale,
            blendMode: blendMode
        ))
    }
}

