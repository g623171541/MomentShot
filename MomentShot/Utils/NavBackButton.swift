//
//  NavBackButton.swift
//  MomentShot
//
//  深色导航栈（图库 / 预览）与浅色表单页共用的左上角返回，避免各页样式不一致。
//

import SwiftUI

struct NavBackButton: View {

    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}
