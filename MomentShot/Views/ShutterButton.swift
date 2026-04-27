//
//  ShutterButton.swift
//  MomentShot
//
//  统一快门键 — App 最核心的交互元件。
//
//  状态机：
//  idle ───tap (松手时累计 < 0.3s)───▶ photo
//  idle ───press 持续 ≥ 0.3s──▶ pressing (进度环开始向 0.5s 充电)
//      ──持续 ≥ 0.5s──▶ recording (开始录像)
//        ──手指松开──▶ stop & 回到 idle
//        ──向上滑动 ≥ 30pt──▶ locked (变方块停止键)
//          ──点击方块──▶ stop & 回到 idle
//
//  使用 Timer 主动驱动进度（DragGesture.onChanged 仅在位移变化时触发，无法靠它做时间累计）。
//

import SwiftUI

enum ShutterPhase: Equatable {
    case idle
    case pressing
    case recording
    case locked
}

struct ShutterButton: View {

    @Binding var phase: ShutterPhase

    let onTapPhoto: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onLockRecording: () -> Void

    @State private var pressStart: Date?
    @State private var dragStartLocation: CGPoint = .zero
    @State private var dragCurrentLocation: CGPoint = .zero
    @State private var progress: Double = 0
    @State private var tickTimer: Timer?

    private let outerSize: CGFloat = 76
    private let innerSize: CGFloat = 60
    private let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            outerRing.frame(width: outerSize, height: outerSize)
            innerCircle
        }
        .frame(width: outerSize + 6, height: outerSize + 6)
        .contentShape(Circle())
        .gesture(dragGesture)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: phase)
        .onChange(of: phase) { newValue in
            if newValue == .idle { progress = 0 }
        }
    }

    // MARK: - 外观

    @ViewBuilder
    private var outerRing: some View {
        switch phase {
        case .idle:
            Circle().stroke(Color.white, lineWidth: lineWidth)
        case .pressing, .recording:
            ZStack {
                Circle().stroke(Color.white.opacity(0.3), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: lineWidth + 1, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        case .locked:
            Circle().stroke(Color.red.opacity(0.9), lineWidth: lineWidth)
        }
    }

    @ViewBuilder
    private var innerCircle: some View {
        switch phase {
        case .idle:
            Circle()
                .fill(Color.white)
                .frame(width: innerSize, height: innerSize)

        case .pressing:
            Circle()
                .fill(Color.white)
                .frame(width: innerSize * 0.85, height: innerSize * 0.85)

        case .recording:
            Circle()
                .fill(Color.red)
                .frame(width: innerSize * 0.6, height: innerSize * 0.6)

        case .locked:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.red)
                .frame(width: innerSize * 0.5, height: innerSize * 0.5)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.medium()
                    onStopRecording()
                }
        }
    }

    // MARK: - 手势

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        // 锁定状态下不响应任何拖拽，需要点击方块才能结束
        if phase == .locked { return }

        if pressStart == nil {
            pressStart = Date()
            dragStartLocation = value.startLocation
            dragCurrentLocation = value.location
            phase = .pressing
            startTimer()
            return
        }

        dragCurrentLocation = value.location

        // 上滑锁定（仅在 recording 阶段生效）
        if phase == .recording {
            let dy = dragStartLocation.y - value.location.y
            if dy >= 30 {
                lockRecording()
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        // 锁定状态下不响应松手
        if phase == .locked { return }

        let elapsed = pressStart.map { Date().timeIntervalSince($0) } ?? 0
        cleanupTimer()
        pressStart = nil

        switch phase {
        case .recording:
            phase = .idle
            onStopRecording()
        case .pressing:
            phase = .idle
            if elapsed < 0.5 {
                HapticManager.medium()
                onTapPhoto()
            } else {
                // 介于 0.5s 与触发录像之间的极少数情况，按拍照处理
                onTapPhoto()
            }
        case .idle, .locked:
            break
        }
    }

    private func lockRecording() {
        cleanupTimer()
        pressStart = nil
        phase = .locked
        progress = 0
        HapticManager.success()
        onLockRecording()
    }

    // MARK: - Timer

    private func startTimer() {
        cleanupTimer()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func cleanupTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        guard let start = pressStart else { return }
        let elapsed = Date().timeIntervalSince(start)

        switch phase {
        case .pressing:
            // 0 → 0.5s 内充电进度环
            let p = min(1.0, elapsed / 0.5)
            progress = p
            if elapsed >= 0.5 {
                HapticManager.medium()
                phase = .recording
                progress = 0
                onStartRecording()
            }
        case .recording:
            // 录像中：进度环按 90s 视觉满
            progress = min(1.0, elapsed / 90.0)
        case .idle, .locked:
            cleanupTimer()
        }
    }
}
