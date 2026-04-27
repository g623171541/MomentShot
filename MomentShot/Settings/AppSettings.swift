//
//  AppSettings.swift
//  MomentShot
//
//  全局偏好设置：通过 UserDefaults 持久化，ObservableObject 让 UI 订阅。
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: - 拍摄参数

    @Published var videoResolution: VideoResolution {
        didSet { defaults.set(videoResolution.rawValue, forKey: Keys.videoResolution) }
    }

    @Published var videoFrameRate: VideoFrameRate {
        didSet { defaults.set(videoFrameRate.rawValue, forKey: Keys.videoFrameRate) }
    }

    @Published var photoResolution: PhotoResolution {
        didSet { defaults.set(photoResolution.rawValue, forKey: Keys.photoResolution) }
    }

    @Published var enableGeoTag: Bool {
        didSet { defaults.set(enableGeoTag, forKey: Keys.enableGeoTag) }
    }

    // MARK: - 长按行为

    @Published var longPressBehavior: LongPressBehavior {
        didSet { defaults.set(longPressBehavior.rawValue, forKey: Keys.longPressBehavior) }
    }

    // MARK: - 音量键

    @Published var volumeButtonAction: VolumeButtonAction {
        didSet { defaults.set(volumeButtonAction.rawValue, forKey: Keys.volumeButtonAction) }
    }

    // MARK: - 静音

    @Published var silentShutter: Bool {
        didSet { defaults.set(silentShutter, forKey: Keys.silentShutter) }
    }

    // MARK: - 触觉反馈

    @Published var hapticEnabled: Bool {
        didSet { defaults.set(hapticEnabled, forKey: Keys.hapticEnabled) }
    }

    // MARK: - 显示辅助

    @Published var showGrid: Bool {
        didSet { defaults.set(showGrid, forKey: Keys.showGrid) }
    }

    @Published var showLevel: Bool {
        didSet { defaults.set(showLevel, forKey: Keys.showLevel) }
    }

    @Published var enableDoubleTapFlip: Bool {
        didSet { defaults.set(enableDoubleTapFlip, forKey: Keys.enableDoubleTapFlip) }
    }

    @Published var enableSingleFingerZoom: Bool {
        didSet { defaults.set(enableSingleFingerZoom, forKey: Keys.enableSingleFingerZoom) }
    }

    // MARK: - 闪光灯（默认状态记忆）

    @Published var flashMode: FlashMode {
        didSet { defaults.set(flashMode.rawValue, forKey: Keys.flashMode) }
    }

    // MARK: - 倒计时

    @Published var countdownMode: CountdownMode {
        didSet { defaults.set(countdownMode.rawValue, forKey: Keys.countdownMode) }
    }

    // MARK: - 镜头位置

    @Published var cameraPosition: CameraPosition {
        didSet { defaults.set(cameraPosition.rawValue, forKey: Keys.cameraPosition) }
    }

    // MARK: -

    private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard

        self.videoResolution = VideoResolution(rawValue: d.string(forKey: Keys.videoResolution) ?? "") ?? .hd1080
        self.videoFrameRate = VideoFrameRate(rawValue: d.integer(forKey: Keys.videoFrameRate) == 0 ? 30 : d.integer(forKey: Keys.videoFrameRate)) ?? .fps30
        self.photoResolution = PhotoResolution(rawValue: d.string(forKey: Keys.photoResolution) ?? "") ?? .high
        self.enableGeoTag = d.object(forKey: Keys.enableGeoTag) as? Bool ?? false
        self.longPressBehavior = LongPressBehavior(rawValue: d.string(forKey: Keys.longPressBehavior) ?? "") ?? .recordVideo
        self.volumeButtonAction = VolumeButtonAction(rawValue: d.string(forKey: Keys.volumeButtonAction) ?? "") ?? .takePhoto
        self.silentShutter = d.object(forKey: Keys.silentShutter) as? Bool ?? false
        self.hapticEnabled = d.object(forKey: Keys.hapticEnabled) as? Bool ?? true
        self.showGrid = d.object(forKey: Keys.showGrid) as? Bool ?? false
        self.showLevel = d.object(forKey: Keys.showLevel) as? Bool ?? false
        self.enableDoubleTapFlip = d.object(forKey: Keys.enableDoubleTapFlip) as? Bool ?? true
        self.enableSingleFingerZoom = d.object(forKey: Keys.enableSingleFingerZoom) as? Bool ?? false
        self.flashMode = FlashMode(rawValue: d.string(forKey: Keys.flashMode) ?? "") ?? .auto
        self.countdownMode = CountdownMode(rawValue: d.integer(forKey: Keys.countdownMode)) ?? .off
        self.cameraPosition = CameraPosition(rawValue: d.string(forKey: Keys.cameraPosition) ?? "") ?? .back
    }

    private enum Keys {
        static let videoResolution      = "settings.videoResolution"
        static let videoFrameRate       = "settings.videoFrameRate"
        static let photoResolution      = "settings.photoResolution"
        static let enableGeoTag         = "settings.enableGeoTag"
        static let longPressBehavior    = "settings.longPressBehavior"
        static let volumeButtonAction   = "settings.volumeButtonAction"
        static let silentShutter        = "settings.silentShutter"
        static let hapticEnabled        = "settings.hapticEnabled"
        static let showGrid             = "settings.showGrid"
        static let showLevel            = "settings.showLevel"
        static let enableDoubleTapFlip  = "settings.enableDoubleTapFlip"
        static let enableSingleFingerZoom = "settings.enableSingleFingerZoom"
        static let flashMode            = "settings.flashMode"
        static let countdownMode        = "settings.countdownMode"
        static let cameraPosition       = "settings.cameraPosition"
    }
}
