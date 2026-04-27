//
//  CameraRootView.swift
//  MomentShot
//
//  主取景界面：
//  - 顶部：闪光灯 / 定时器 / 设置
//  - 中部：取景器（点击对焦/长按 AE-AF 锁定/双击切换镜头/双指变焦/单指变焦条）
//  - 底部：缩略图 / 快门 / 镜头切换
//  - 录像中：顶部红色计时条；锁定时其它按钮灰显
//

import AVFoundation
import SwiftUI

struct CameraRootView: View {

    @StateObject private var camera = CameraService()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var index = MediaIndex.shared
    @StateObject private var permission = PermissionManager.shared

    // 取景器交互状态
    @State private var previewView: PreviewBackingView?
    @State private var focusInfo: FocusInfo?
    @State private var lastZoomBeforeGesture: CGFloat = 1.0
    @State private var showZoomIndicator: Bool = false
    @State private var zoomIndicatorTimer: Timer?

    @State private var shutterPhase: ShutterPhase = .idle

    // 倒计时
    @State private var countdownRemaining: Int = 0
    @State private var countdownTimer: Timer?
    @State private var pendingActionAfterCountdown: PendingAction = .none

    // 闪白动画
    @State private var flashScreenWhite: Bool = false

    // 错误提示
    @State private var errorMessage: String?

    // 浏览器（阶段 4 占位 - 本轮先跳到一个空的 sheet）
    @State private var showBrowser = false

    // 设置（阶段 5 占位 - 本轮先跳到一个空的 sheet）
    @State private var showSettings = false

    private enum PendingAction {
        case none, photo, recordStart
    }

    private struct FocusInfo: Equatable {
        let id = UUID()
        let location: CGPoint
        let isLocked: Bool
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 取景层
                if permission.cameraGranted {
                    cameraPreviewLayer(in: geo)
                } else {
                    permissionPlaceholder
                }

                // 网格
                if settings.showGrid {
                    GridOverlayView()
                        .padding(.horizontal, 0)
                        .ignoresSafeArea()
                }

                // 对焦框 + 曝光滑杆
                if let info = focusInfo {
                    FocusOverlayView(
                        position: info.location,
                        isLocked: info.isLocked,
                        exposureBias: Binding(
                            get: { camera.exposureBias },
                            set: { _ in }
                        ),
                        minBias: camera.minExposureBias,
                        maxBias: camera.maxExposureBias,
                        onChangeBias: { camera.setExposureBias($0) }
                    )
                    .id(info.id)
                    .allowsHitTesting(true)
                    .transition(.opacity)
                }

                // 闪白快门动画
                if flashScreenWhite {
                    Color.white
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // 倒计时浮层
                if countdownRemaining > 0 {
                    CountdownOverlayView(seconds: countdownRemaining) {
                        cancelCountdown()
                    }
                    .transition(.opacity)
                }

                // 顶部 + 底部 控件
                VStack {
                    topBar
                        .padding(.top, 8)

                    Spacer()

                    if showZoomIndicator {
                        ZoomIndicatorView(zoom: camera.currentZoomFactor)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }

                    if settings.enableSingleFingerZoom {
                        zoomBar
                            .padding(.bottom, 8)
                    }

                    bottomBar
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 8)

                // 错误提示
                if let msg = errorMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                            .padding(.bottom, 200)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .task { await camera.bootstrap(initialPosition: settings.cameraPosition) }
        .onAppear {
            wireCameraCallbacks()
            camera.setFlashMode(settings.flashMode)
        }
        .onChange(of: settings.flashMode) { camera.setFlashMode($0) }
        .onDisappear { camera.stopSession() }
        .onChange(of: camera.lastError) { newValue in
            guard let msg = newValue, !msg.isEmpty else { return }
            showError(msg)
        }
        .onChange(of: camera.position) { settings.cameraPosition = $0 }
        .sheet(isPresented: $showBrowser) {
            // 阶段 4 占位
            BrowserPlaceholderView()
        }
        .sheet(isPresented: $showSettings) {
            // 阶段 5 占位
            SettingsPlaceholderView()
        }
    }

    // MARK: - 取景器层

    private func cameraPreviewLayer(in geo: GeometryProxy) -> some View {
        ZStack {
            CameraPreviewView(session: camera.session) { view in
                self.previewView = view
                wirePreviewGestures(on: view)
            }
            .ignoresSafeArea()

            // 录像状态顶部红条（独立挂在最上）
            if camera.isRecording || shutterPhase == .locked {
                VStack {
                    HStack {
                        Spacer()
                        RecordingIndicatorView(duration: camera.recordingDuration)
                        Spacer()
                    }
                    .padding(.top, 12)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }

    private func wirePreviewGestures(on view: PreviewBackingView) {
        view.onSingleTap = { location in
            handleFocusTap(at: location, lock: false)
        }
        view.onLongPress = { location in
            handleFocusTap(at: location, lock: true)
        }
        view.onDoubleTap = {
            guard settings.enableDoubleTapFlip else { return }
            guard !camera.isRecording, shutterPhase != .locked else { return }
            camera.switchCamera()
        }
        view.onPinch = { scale, state in
            switch state {
            case .began:
                lastZoomBeforeGesture = camera.currentZoomFactor
            case .changed:
                let target = lastZoomBeforeGesture * scale
                camera.setZoom(target)
                triggerZoomIndicator()
            case .ended, .cancelled, .failed:
                lastZoomBeforeGesture = camera.currentZoomFactor
            default:
                break
            }
        }
    }

    private var permissionPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.white.opacity(0.6))
            Text("MomentShot 需要相机权限才能拍摄")
                .font(.headline)
                .foregroundColor(.white)
            Button("去『设置』开启") {
                permission.openAppSettings()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundColor(.black)
        }
    }

    // MARK: - 顶栏 / 底栏

    private var topBar: some View {
        TopToolbarView(
            flashMode: $settings.flashMode,
            countdownMode: $settings.countdownMode,
            onTapSettings: { showSettings = true },
            isDisabled: camera.isRecording || shutterPhase == .locked
        )
    }

    private var bottomBar: some View {
        HStack {
            ThumbnailButton(item: index.latest) {
                showBrowser = true
            }
            .disabled(camera.isRecording || shutterPhase == .locked)
            .opacity((camera.isRecording || shutterPhase == .locked) ? 0.4 : 1)

            Spacer()

            ShutterButton(
                phase: $shutterPhase,
                onTapPhoto: handleTapPhoto,
                onStartRecording: handleStartRecording,
                onStopRecording: handleStopRecording,
                onLockRecording: handleLockRecording
            )

            Spacer()

            Button {
                guard !camera.isRecording, shutterPhase != .locked else { return }
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .disabled(camera.isRecording || shutterPhase == .locked)
            .opacity((camera.isRecording || shutterPhase == .locked) ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
    }

    private var zoomBar: some View {
        let bounds = camera.minZoomFactor...max(camera.minZoomFactor + 0.1, camera.maxZoomFactor)
        return HStack {
            Image(systemName: "minus.magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
            Slider(
                value: Binding(
                    get: { Double(camera.currentZoomFactor) },
                    set: { newVal in
                        camera.setZoom(CGFloat(newVal))
                        triggerZoomIndicator()
                    }
                ),
                in: Double(bounds.lowerBound)...Double(bounds.upperBound)
            )
            .tint(.yellow)
            Image(systemName: "plus.magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.3)))
        .padding(.horizontal, 16)
    }

    // MARK: - 取景器交互

    private func handleFocusTap(at location: CGPoint, lock: Bool) {
        guard let view = previewView else { return }
        let devicePoint = view.videoLayer.captureDevicePointConverted(fromLayerPoint: location)

        camera.focus(at: devicePoint, lockExposureAndFocus: lock)

        // 重置曝光补偿（点击新点时）
        camera.setExposureBias(0)

        focusInfo = FocusInfo(location: location, isLocked: lock)
        if lock { HapticManager.success() } else { HapticManager.light() }

        // 自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if focusInfo?.location == location {
                focusInfo = nil
            }
        }
    }

    private func triggerZoomIndicator() {
        showZoomIndicator = true
        zoomIndicatorTimer?.invalidate()
        zoomIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { showZoomIndicator = false }
            }
        }
    }

    // MARK: - 拍照 / 录像

    private func wireCameraCallbacks() {
        camera.onPhotoCaptured = { item in
            MediaIndex.shared.add(item)
            HapticManager.success()
        }
        camera.onVideoRecorded = { item in
            MediaIndex.shared.add(item)
            HapticManager.success()
        }
    }

    private func handleTapPhoto() {
        // 点按拍照：考虑倒计时
        if settings.countdownMode != .off {
            startCountdown(action: .photo)
            return
        }
        triggerWhiteFlash()
        camera.capturePhoto()
    }

    private func handleStartRecording() {
        // 长按行为：录像 or 连拍
        if settings.longPressBehavior == .burst {
            // 连拍 — 阶段 4 实现，本轮提示
            showError("高速连拍将在后续版本中提供")
            // 同时回到 idle 状态
            shutterPhase = .idle
            return
        }
        // 倒计时模式下也直接开录
        camera.startRecording()
    }

    private func handleStopRecording() {
        camera.stopRecording()
    }

    private func handleLockRecording() {
        // 仅 UI 状态翻转，无需新开录像
    }

    private func triggerWhiteFlash() {
        withAnimation(.easeOut(duration: 0.05)) { flashScreenWhite = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.easeIn(duration: 0.15)) { flashScreenWhite = false }
        }
    }

    // MARK: - 倒计时

    private func startCountdown(action: PendingAction) {
        cancelCountdown()
        pendingActionAfterCountdown = action
        countdownRemaining = settings.countdownMode.rawValue
        guard countdownRemaining > 0 else {
            performPendingAction()
            return
        }
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                countdownRemaining -= 1
                HapticManager.light()
                if countdownRemaining <= 0 {
                    cancelCountdownTimerOnly()
                    performPendingAction()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func cancelCountdown() {
        cancelCountdownTimerOnly()
        countdownRemaining = 0
        pendingActionAfterCountdown = .none
    }

    private func cancelCountdownTimerOnly() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func performPendingAction() {
        switch pendingActionAfterCountdown {
        case .photo:
            triggerWhiteFlash()
            camera.capturePhoto()
        case .recordStart:
            camera.startRecording()
        case .none:
            break
        }
        pendingActionAfterCountdown = .none
        countdownRemaining = 0
    }

    // MARK: - 错误

    private func showError(_ msg: String) {
        withAnimation(.spring()) { errorMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { errorMessage = nil }
        }
    }
}

// MARK: - 阶段 4/5 占位（下一轮替换）

private struct BrowserPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.7))
                Text("媒体浏览器（阶段 4 实现）")
                    .foregroundColor(.white)
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            Form {
                Section("长按行为") {
                    Picker("长按快门键", selection: $settings.longPressBehavior) {
                        ForEach(LongPressBehavior.allCases) { Text($0.displayLabel).tag($0) }
                    }
                }
                Section("显示辅助") {
                    Toggle("九宫格", isOn: $settings.showGrid)
                    Toggle("水平仪（即将上线）", isOn: $settings.showLevel).disabled(true)
                    Toggle("双击空白切换镜头", isOn: $settings.enableDoubleTapFlip)
                    Toggle("单指变焦条", isOn: $settings.enableSingleFingerZoom)
                }
                Section("反馈") {
                    Toggle("触觉反馈", isOn: $settings.hapticEnabled)
                    Toggle("静音拍摄（需符合地区法规）", isOn: $settings.silentShutter)
                }
                Section("拍摄参数") {
                    Picker("视频分辨率", selection: $settings.videoResolution) {
                        ForEach(VideoResolution.allCases) { Text($0.displayLabel).tag($0) }
                    }
                    Picker("视频帧率", selection: $settings.videoFrameRate) {
                        ForEach(VideoFrameRate.allCases) { Text($0.displayLabel).tag($0) }
                    }
                    Picker("照片质量", selection: $settings.photoResolution) {
                        ForEach(PhotoResolution.allCases) { Text($0.displayLabel).tag($0) }
                    }
                }
                Section("提示") {
                    Text("完整设置（音量键 / 存储管理等）将在下一阶段提供。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
