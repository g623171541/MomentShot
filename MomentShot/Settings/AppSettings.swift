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
        didSet {
            defaults.set(videoResolution.width, forKey: Keys.videoResolutionWidth)
            defaults.set(videoResolution.height, forKey: Keys.videoResolutionHeight)
        }
    }

    @Published var videoFrameRate: VideoFrameRate {
        didSet { defaults.set(videoFrameRate.fps, forKey: Keys.videoFrameRate) }
    }

    @Published var photoResolution: PhotoResolution {
        didSet { defaults.set(photoResolution.rawValue, forKey: Keys.photoResolution) }
    }

    @Published var enableGeoTag: Bool {
        didSet { defaults.set(enableGeoTag, forKey: Keys.enableGeoTag) }
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

    @Published var enableDoubleTapFlip: Bool {
        didSet { defaults.set(enableDoubleTapFlip, forKey: Keys.enableDoubleTapFlip) }
    }

    @Published var enableSingleFingerZoom: Bool {
        didSet { defaults.set(enableSingleFingerZoom, forKey: Keys.enableSingleFingerZoom) }
    }

    // MARK: - 镜头位置

    @Published var cameraPosition: CameraPosition {
        didSet { defaults.set(cameraPosition.rawValue, forKey: Keys.cameraPosition) }
    }

    // MARK: -

    private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard

        let storedW = d.integer(forKey: Keys.videoResolutionWidth)
        let storedH = d.integer(forKey: Keys.videoResolutionHeight)
        self.videoResolution = (storedW > 0 && storedH > 0)
            ? VideoResolution(width: storedW, height: storedH)
            : .default

        let storedFPS = d.integer(forKey: Keys.videoFrameRate)
        self.videoFrameRate = storedFPS > 0 ? VideoFrameRate(fps: storedFPS) : .default

        self.photoResolution = PhotoResolution(rawValue: d.string(forKey: Keys.photoResolution) ?? "") ?? .high
        self.enableGeoTag = d.object(forKey: Keys.enableGeoTag) as? Bool ?? false
        self.volumeButtonAction = VolumeButtonAction(rawValue: d.string(forKey: Keys.volumeButtonAction) ?? "") ?? .takePhoto
        self.silentShutter = d.object(forKey: Keys.silentShutter) as? Bool ?? false
        self.hapticEnabled = d.object(forKey: Keys.hapticEnabled) as? Bool ?? true
        self.enableDoubleTapFlip = d.object(forKey: Keys.enableDoubleTapFlip) as? Bool ?? true
        self.enableSingleFingerZoom = d.object(forKey: Keys.enableSingleFingerZoom) as? Bool ?? false
        self.cameraPosition = CameraPosition(rawValue: d.string(forKey: Keys.cameraPosition) ?? "") ?? .back
    }

    private enum Keys {
        static let videoResolutionWidth  = "settings.videoResolution.width"
        static let videoResolutionHeight = "settings.videoResolution.height"
        static let videoFrameRate        = "settings.videoFrameRate"
        static let photoResolution       = "settings.photoResolution"
        static let enableGeoTag          = "settings.enableGeoTag"
        static let volumeButtonAction    = "settings.volumeButtonAction"
        static let silentShutter         = "settings.silentShutter"
        static let hapticEnabled         = "settings.hapticEnabled"
        static let enableDoubleTapFlip   = "settings.enableDoubleTapFlip"
        static let enableSingleFingerZoom = "settings.enableSingleFingerZoom"
        static let cameraPosition        = "settings.cameraPosition"
    }
}
