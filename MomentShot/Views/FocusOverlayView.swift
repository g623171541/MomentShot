//
//  FocusOverlayView.swift
//  MomentShot
//
//  对焦框 + 右侧曝光滑杆。
//  - 对焦框：白色描边，从 1.5x 缩放到 1.0x，显示 1.5s 后自动淡出
//  - 锁定时显示 AE/AF 黄色标签
//  - 曝光滑杆：按住小太阳上下拖拽，把 dy 映射到 [-2, +2]
//

import SwiftUI

struct FocusOverlayView: View {

    let position: CGPoint
    let isLocked: Bool

    @Binding var exposureBias: Float
    let minBias: Float
    let maxBias: Float
    let onChangeBias: (Float) -> Void

    @State private var animatedScale: CGFloat = 1.5
    @State private var animatedOpacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 对焦框
            ZStack {
                Rectangle()
                    .stroke(isLocked ? Color.yellow : Color.white, lineWidth: 1.2)
                    .frame(width: 80, height: 80)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                        .offset(x: -36, y: -36)
                }

                // 曝光滑杆挂在右侧
                exposureSlider
                    .offset(x: 60, y: 0)
            }
            .scaleEffect(animatedScale)
            .opacity(animatedOpacity)
            .position(position)
            .onAppear {
                animatedScale = 1.5
                animatedOpacity = 1.0
                withAnimation(.easeOut(duration: 0.25)) {
                    animatedScale = 1.0
                }
                withAnimation(.easeIn(duration: 0.4).delay(2.0)) {
                    animatedOpacity = 0.4
                }
            }
        }
    }

    private var exposureSlider: some View {
        let track: CGFloat = 90
        return VStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.yellow)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // dy 越小（手指越往上）数值越大
                            let dy = -Double(value.translation.height) / Double(track)
                            let span = Double(maxBias - minBias)
                            let mid = Double((maxBias + minBias) / 2)
                            let target = mid + dy * span
                            let clamped = Float(max(Double(minBias), min(Double(maxBias), target)))
                            exposureBias = clamped
                            onChangeBias(clamped)
                        }
                )
            Rectangle()
                .fill(Color.yellow.opacity(0.6))
                .frame(width: 1, height: track)
        }
    }
}

struct ZoomIndicatorView: View {

    let zoom: CGFloat

    var body: some View {
        Text(String(format: "%.1fx", zoom))
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundColor(.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.45)))
    }
}
