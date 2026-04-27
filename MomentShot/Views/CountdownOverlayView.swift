//
//  CountdownOverlayView.swift
//  MomentShot
//
//  3s/10s 倒计时浮层，点击屏幕中部数字可取消。
//

import SwiftUI

struct CountdownOverlayView: View {

    let seconds: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            Text("\(seconds)")
                .font(.system(size: 140, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 10)
                .transition(.scale.combined(with: .opacity))
                .id(seconds)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.light()
            onCancel()
        }
    }
}
