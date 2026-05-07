//
//  CameraService.swift
//  MomentShot
//
//  AVCaptureSession 的完整封装：搭建、镜头切换、对焦/测光、变焦、
//  拍照与录像。会话操作均派发到 sessionQueue，UI 状态通过 @Published 暴露。
//

import AVFoundation
import Combine
import Foundation
import Photos
import UIKit

final class CameraService: NSObject, ObservableObject {

    // MARK: - 对外发布的 UI 状态

    @Published private(set) var isSessionRunning: Bool = false
    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var setupError: String?

    @Published private(set) var position: CameraPosition = .back

    @Published private(set) var isRecording: Bool = false
    @Published private(set) var recordingDuration: TimeInterval = 0

    @Published private(set) var currentZoomFactor: CGFloat = 1.0
    @Published private(set) var minZoomFactor: CGFloat = 1.0
    @Published private(set) var maxZoomFactor: CGFloat = 5.0

    @Published private(set) var exposureBias: Float = 0
    @Published private(set) var minExposureBias: Float = -2
    @Published private(set) var maxExposureBias: Float = 2

    @Published private(set) var isAEAFLocked: Bool = false

    @Published private(set) var lastError: String?

    // MARK: - 完成事件

    /// 拍照成功后回调（主线程）
    var onPhotoCaptured: ((MediaItem) -> Void)?
    /// 录像成功后回调（主线程）
    var onVideoRecorded: ((MediaItem) -> Void)?

    // MARK: - 内部

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.paddy.MomentShot.cameraSession", qos: .userInitiated)

    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?

    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()

    private var recordingStartDate: Date?
    private var recordingTimer: Timer?

    // 同时持有 delegate 以保活
    private var photoDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var movieDelegate: MovieRecorderDelegate?

    // MARK: - 生命周期

    override init() {
        super.init()
    }

    /// 第一次进入界面时调用：申请权限 + 初始化 session
    func bootstrap(initialPosition: CameraPosition) async {
        let camOK = await PermissionManager.shared.requestCameraIfNeeded()
        guard camOK else {
            await MainActor.run {
                self.setupError = "缺少相机权限。请在『设置』中开启。"
            }
            return
        }
        // 录像必备麦克风权限，但不强制拒绝时阻断拍照
        _ = await PermissionManager.shared.requestMicrophoneIfNeeded()

        await MainActor.run { self.position = initialPosition }

        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.session.isRunning ?? false
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    // MARK: - 会话搭建

    private func configureSession() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 使用 .inputPriority 使我们手动指定的 device.activeFormat 不被 session 覆盖
        if session.canSetSessionPreset(.inputPriority) {
            session.sessionPreset = .inputPriority
        }

        do {
            try addVideoInput(for: position)
            try addAudioInput()
            try addPhotoOutput()
            try addMovieOutput()
            DispatchQueue.main.async {
                self.isConfigured = true
                self.refreshZoomBoundsFromCurrentDevice()
                self.refreshExposureBoundsFromCurrentDevice()
            }
        } catch {
            DispatchQueue.main.async {
                self.setupError = error.localizedDescription
            }
        }
    }

    private func addVideoInput(for position: CameraPosition) throws {
        let avPosition: AVCaptureDevice.Position = (position == .front) ? .front : .back
        guard let device = bestDevice(for: avPosition) else {
            throw NSError(domain: "CameraService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "未找到可用的摄像头"
            ])
        }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
        } else {
            throw NSError(domain: "CameraService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "无法添加视频输入"
            ])
        }
        applyFormatAndFrameRate(to: device)
    }

    private func addAudioInput() throws {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        let input = try AVCaptureDeviceInput(device: audioDevice)
        if session.canAddInput(input) {
            session.addInput(input)
            audioDeviceInput = input
        }
    }

    private func addPhotoOutput() throws {
        guard session.canAddOutput(photoOutput) else {
            throw NSError(domain: "CameraService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "无法添加拍照输出"
            ])
        }
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
    }

    private func addMovieOutput() throws {
        guard session.canAddOutput(movieOutput) else {
            throw NSError(domain: "CameraService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "无法添加录像输出"
            ])
        }
        session.addOutput(movieOutput)
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
    }

    private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let pos: CameraPosition = (position == .front) ? .front : .back
        return CameraCapabilities.device(for: pos)
    }

    /// 把 AppSettings 偏好的分辨率/帧率应用到 device.activeFormat。
    /// 若设备不支持偏好值，会自动回退到该镜头位置上最接近的可用项。
    private func applyFormatAndFrameRate(to device: AVCaptureDevice) {
        let pos: CameraPosition = (device.position == .front) ? .front : .back

        let prefRes = AppSettings.shared.videoResolution
        let supportedRes = CameraCapabilities.supportedResolutions(for: pos)
        let resolved: VideoResolution = {
            if supportedRes.contains(where: { $0 == prefRes }) { return prefRes }
            // 回退：选不大于偏好值的最大支持项
            if let down = supportedRes.first(where: { $0.pixels <= prefRes.pixels }) {
                return down
            }
            return supportedRes.first ?? prefRes
        }()

        let prefFPS = AppSettings.shared.videoFrameRate.fps
        let supportedFPS = CameraCapabilities.supportedFrameRates(for: pos, resolution: resolved).map(\.fps)
        let resolvedFPS: Int = supportedFPS.contains(prefFPS) ? prefFPS : (supportedFPS.last ?? 30)

        guard let format = CameraCapabilities.bestFormat(
            for: device,
            targetWidth: resolved.width,
            targetHeight: resolved.height,
            targetFPS: resolvedFPS
        ) else { return }

        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(resolvedFPS))
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(resolvedFPS))
            device.unlockForConfiguration()
        } catch {
            // 忽略：不致命
        }

        // 当存储的偏好被回退时，把 AppSettings 同步回真实生效值，避免 UI 显示不一致
        if resolved != prefRes || resolvedFPS != prefFPS {
            DispatchQueue.main.async {
                if AppSettings.shared.videoResolution != resolved {
                    AppSettings.shared.videoResolution = resolved
                }
                if AppSettings.shared.videoFrameRate.fps != resolvedFPS {
                    AppSettings.shared.videoFrameRate = VideoFrameRate(fps: resolvedFPS)
                }
            }
        }
    }

    /// 设置面板修改了分辨率/帧率后调用：在不重建会话的情况下重新应用 device 配置。
    func applyVideoSettings() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            self.session.beginConfiguration()
            self.applyFormatAndFrameRate(to: device)
            self.session.commitConfiguration()
            DispatchQueue.main.async {
                self.refreshZoomBoundsFromCurrentDevice()
            }
        }
    }

    // MARK: - 镜头切换

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self,
                  let currentInput = self.videoDeviceInput else { return }
            let newPosition: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
            guard let newDevice = self.bestDevice(for: newPosition) else { return }
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                self.session.beginConfiguration()
                self.session.removeInput(currentInput)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                } else {
                    self.session.addInput(currentInput)
                }
                self.session.commitConfiguration()
                self.applyFormatAndFrameRate(to: newDevice)

                DispatchQueue.main.async {
                    self.position = (newPosition == .front) ? .front : .back
                    self.refreshZoomBoundsFromCurrentDevice()
                    self.refreshExposureBoundsFromCurrentDevice()
                    self.currentZoomFactor = newDevice.videoZoomFactor
                    self.exposureBias = newDevice.exposureTargetBias
                    self.isAEAFLocked = false
                    HapticManager.light()
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastError = "切换镜头失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 对焦 & 测光（POI 取自预览层归一化坐标）

    /// devicePoint: AVCaptureVideoPreviewLayer.captureDevicePointConverted(...) 得到的归一化坐标 [0,1]
    func focus(at devicePoint: CGPoint, lockExposureAndFocus: Bool = false) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                }
                if lockExposureAndFocus {
                    if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
                    if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
                } else {
                    if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                }
                device.isSubjectAreaChangeMonitoringEnabled = !lockExposureAndFocus
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self?.isAEAFLocked = lockExposureAndFocus
                }
            } catch {
                // 忽略
            }
        }
    }

    func unlockExposureAndFocus() {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
                DispatchQueue.main.async { self?.isAEAFLocked = false }
            } catch {}
        }
    }

    // MARK: - 曝光补偿

    private func refreshExposureBoundsFromCurrentDevice() {
        guard let device = videoDeviceInput?.device else { return }
        minExposureBias = device.minExposureTargetBias
        maxExposureBias = device.maxExposureTargetBias
        exposureBias = device.exposureTargetBias
    }

    func setExposureBias(_ value: Float) {
        let clamped = max(minExposureBias, min(maxExposureBias, value))
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
                DispatchQueue.main.async { self?.exposureBias = clamped }
            } catch {}
        }
    }

    // MARK: - 变焦

    private func refreshZoomBoundsFromCurrentDevice() {
        guard let device = videoDeviceInput?.device else { return }
        let lowest: CGFloat = 1.0
        // 部分超广角设备实际的最小 zoomFactor 可能 > 1，PRD 要求 0.5x 起，但这里以设备真实下限为准
        minZoomFactor = max(lowest, device.minAvailableVideoZoomFactor)
        maxZoomFactor = min(5.0, device.maxAvailableVideoZoomFactor)
        currentZoomFactor = max(minZoomFactor, min(maxZoomFactor, device.videoZoomFactor))
    }

    func setZoom(_ factor: CGFloat, ramp: Bool = false) {
        let clamped = max(minZoomFactor, min(maxZoomFactor, factor))
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if ramp {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 4.0)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async { self?.currentZoomFactor = clamped }
            } catch {}
        }
    }

    // MARK: - 拍照

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = self.makePhotoSettings()
            let delegate = PhotoCaptureDelegate(
                position: self.position,
                onFinished: { [weak self] item, error in
                    if let item = item {
                        DispatchQueue.main.async { self?.onPhotoCaptured?(item) }
                    } else if let error = error {
                        DispatchQueue.main.async { self?.lastError = error.localizedDescription }
                    }
                    self?.sessionQueue.async {
                        self?.photoDelegates.removeValue(forKey: settings.uniqueID)
                    }
                }
            )
            self.photoDelegates[settings.uniqueID] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func makePhotoSettings() -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.flashMode = .off
        settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
        return settings
    }

    // MARK: - 录像

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self, !self.movieOutput.isRecording else { return }

            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if self.position == .front, connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }

            // 使用 .mov 扩展名，AVCaptureMovieFileOutput 默认使用 QuickTime 容器
            let fileName = MediaStore.makeFileName(type: .video, ext: "mov")
            let url = MediaStore.makeAbsoluteURL(for: .video, fileName: fileName)
            MediaStore.bootstrap()

            let delegate = MovieRecorderDelegate(
                fileName: fileName,
                onFinished: { [weak self] item, error in
                    if let item = item {
                        DispatchQueue.main.async { self?.onVideoRecorded?(item) }
                    } else if let error = error {
                        DispatchQueue.main.async { self?.lastError = error.localizedDescription }
                    }
                    self?.sessionQueue.async { self?.movieDelegate = nil }
                }
            )
            self.movieDelegate = delegate

            self.movieOutput.startRecording(to: url, recordingDelegate: delegate)

            DispatchQueue.main.async {
                self.recordingStartDate = Date()
                self.isRecording = true
                self.recordingDuration = 0
                self.startRecordingTimer()
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
        DispatchQueue.main.async { [weak self] in
            self?.stopRecordingTimer()
            self?.isRecording = false
        }
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartDate else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }
        RunLoop.main.add(timer, forMode: .common)
        recordingTimer = timer
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - PhotoCaptureDelegate

nonisolated private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    private let position: CameraPosition
    private let onFinished: (MediaItem?, Error?) -> Void

    init(position: CameraPosition, onFinished: @escaping (MediaItem?, Error?) -> Void) {
        self.position = position
        self.onFinished = onFinished
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            onFinished(nil, error)
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            onFinished(nil, NSError(domain: "Photo", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "拍照失败：无法生成图像数据"
            ]))
            return
        }
        do {
            let date = Date()
            let fileName = MediaStore.makeFileName(type: .photo, ext: "jpg", at: date)
            let url = try MediaStore.writePhotoData(data, fileName: fileName)
            let size = MediaStore.fileSize(at: url)
            let dimensions = imageDimensions(from: data) ?? .zero
            let item = MediaItem(
                type: .photo,
                fileName: fileName,
                relativePath: MediaStore.relativePath(for: .photo, fileName: fileName),
                createdAt: date,
                width: Int(dimensions.width),
                height: Int(dimensions.height),
                fileSize: size
            )
            onFinished(item, nil)
        } catch {
            onFinished(nil, error)
        }
    }

    private func imageDimensions(from data: Data) -> CGSize? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = image.scale
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}

// MARK: - MovieRecorderDelegate

nonisolated private final class MovieRecorderDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {

    private let fileName: String
    private let onFinished: (MediaItem?, Error?) -> Void

    init(fileName: String, onFinished: @escaping (MediaItem?, Error?) -> Void) {
        self.fileName = fileName
        self.onFinished = onFinished
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // 用户主动停止录像时，CaptureMovieFileOutput 也会回调 error，需要识别忽略
        if let nsErr = error as NSError?,
           nsErr.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true {
            // success
        } else if let error = error {
            try? FileManager.default.removeItem(at: outputFileURL)
            onFinished(nil, error)
            return
        }

        let metadata = MediaStore.videoMetadata(at: outputFileURL)
        let size = MediaStore.fileSize(at: outputFileURL)
        let item = MediaItem(
            type: .video,
            fileName: fileName,
            relativePath: MediaStore.relativePath(for: .video, fileName: fileName),
            createdAt: Date(),
            width: Int(metadata.size.width),
            height: Int(metadata.size.height),
            fileSize: size,
            duration: metadata.duration
        )
        onFinished(item, nil)
    }
}
