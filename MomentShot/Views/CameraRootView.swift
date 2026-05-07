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
    @StateObject private var volumeButton = VolumeButtonObserver()

    // 取景器交互状态
    @State private var previewView: PreviewBackingView?
    @State private var focusInfo: FocusInfo?
    @State private var lastZoomBeforeGesture: CGFloat = 1.0
    @State private var showZoomIndicator: Bool = false
    @State private var zoomIndicatorTimer: Timer?

    @State private var shutterPhase: ShutterPhase = .idle

    // 闪白动画
    @State private var flashScreenWhite: Bool = false

    // 错误提示
    @State private var errorMessage: String?

    /// 是否已推入设置页（与图库相同，横向 push）
    @State private var showSettings = false

    private struct FocusInfo: Equatable {
        let id = UUID()
        let location: CGPoint
        let isLocked: Bool
    }

    var body: some View {
        NavigationView {
            cameraScreen
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var cameraScreen: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 取景层
                if permission.cameraGranted {
                    cameraPreviewLayer(in: geo)
                } else {
                    permissionPlaceholder
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
            wireVolumeButton()
            volumeButton.start()
        }
        .onDisappear {
            camera.stopSession()
            volumeButton.stop()
        }
        .onChange(of: camera.lastError) { newValue in
            guard let msg = newValue, !msg.isEmpty else { return }
            showError(msg)
        }
        .onChange(of: camera.position) { settings.cameraPosition = $0 }
        .onChange(of: showSettings) { isOpen in
            if !isOpen { camera.applyVideoSettings() }
        }
        .background(settingsNavigationLink)
    }

    /// 隐藏 NavigationLink，由齿轮按钮置 `showSettings = true` 触发横向 push
    private var settingsNavigationLink: some View {
        NavigationLink(
            destination: SettingsContentView(cameraPosition: camera.position),
            isActive: $showSettings
        ) {
            EmptyView()
        }
        .frame(width: 0, height: 0)
        .hidden()
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
            onTapSettings: { showSettings = true },
            isDisabled: camera.isRecording || shutterPhase == .locked
        )
    }

    private var bottomBar: some View {
        HStack {
            NavigationLink {
                MediaLibraryView()
            } label: {
                ThumbnailButton(item: index.latest)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { HapticManager.light() })
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

    /// 把 AppSettings.volumeButtonAction 映射成实际行为
    private func wireVolumeButton() {
        volumeButton.onPress = { _ in
            // 浏览器 / 设置 打开时不响应，避免误触
            // 设置页打开时不响应；进入相册（NavigationLink）后 onDisappear 会停掉 KVO
            guard !showSettings else { return }

            switch settings.volumeButtonAction {
            case .takePhoto:
                if camera.isRecording || shutterPhase == .locked { return }
                handleTapPhoto()
            case .toggleRecording:
                if camera.isRecording {
                    camera.stopRecording()
                    shutterPhase = .idle
                } else {
                    handleStartRecording()
                    shutterPhase = .recording
                }
            case .zoom:
                let target = camera.currentZoomFactor < camera.maxZoomFactor ? camera.currentZoomFactor + 0.5 : camera.minZoomFactor
                camera.setZoom(target, ramp: true)
                triggerZoomIndicator()
            case .disabled:
                break
            }
        }
    }

    private func handleTapPhoto() {
        triggerWhiteFlash()
        camera.capturePhoto()
    }

    private func handleStartRecording() {
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

    // MARK: - 错误

    private func showError(_ msg: String) {
        withAnimation(.spring()) { errorMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { errorMessage = nil }
        }
    }
}

