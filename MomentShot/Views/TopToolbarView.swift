//
//  TopToolbarView.swift
//  MomentShot
//

import SwiftUI

struct TopToolbarView: View {

    @Binding var flashMode: FlashMode
    @Binding var countdownMode: CountdownMode
    let onTapSettings: () -> Void
    let isDisabled: Bool

    var body: some View {
        HStack {
            FlashToggleButton(mode: $flashMode)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.4 : 1)

            Spacer()

            CountdownToggleButton(mode: $countdownMode)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.4 : 1)

            Spacer()

            SettingsButton(onTap: onTapSettings)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
    }
}

private struct FlashToggleButton: View {
    @Binding var mode: FlashMode

    var body: some View {
        Button {
            HapticManager.light()
            mode = mode.next()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: mode.systemImageName)
                    .font(.system(size: 18, weight: .semibold))
                Text(mode.displayLabel)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(mode == .off ? .white.opacity(0.6) : .yellow)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(Color.black.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CountdownToggleButton: View {
    @Binding var mode: CountdownMode

    var body: some View {
        Button {
            HapticManager.light()
            mode = mode.next()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .semibold))
                Text(mode.displayLabel)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(mode == .off ? .white.opacity(0.7) : .yellow)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(Color.black.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
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
