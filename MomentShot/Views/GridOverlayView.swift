//
//  GridOverlayView.swift
//  MomentShot
//
//  九宫格参考线。水平仪先按需求实现一个简单的"占位提示"——本轮跳过 CoreMotion。
//

import SwiftUI

struct GridOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                for i in 1...2 {
                    let x = w * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                }
                for i in 1...2 {
                    let y = h * CGFloat(i) / 3
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
