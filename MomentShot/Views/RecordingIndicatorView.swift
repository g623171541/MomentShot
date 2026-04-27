//
//  RecordingIndicatorView.swift
//  MomentShot
//
//  录像中顶部的红色背景 + 闪烁红点 + 计时(分:秒)。
//

import SwiftUI

struct RecordingIndicatorView: View {

    let duration: TimeInterval
    @State private var blink = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(blink ? 0.2 : 1)
                .animation(.easeInOut(duration: 0.6).repeatForever(), value: blink)
            Text(format(duration))
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.red.opacity(0.55))
        )
        .onAppear { blink = true }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
