//
//  TopToolbarView.swift
//  MomentShot
//

import SwiftUI

struct TopToolbarView: View {

    let onTapSettings: () -> Void
    let isDisabled: Bool

    var body: some View {
        HStack {
            Spacer()

            SettingsButton(onTap: onTapSettings)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
    }
}

private struct SettingsButton: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            onTap()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(Color.black.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
    }
}
