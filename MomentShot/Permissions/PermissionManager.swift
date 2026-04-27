//
//  PermissionManager.swift
//  MomentShot
//
//  统一管理相机/麦克风权限。所有照片/视频默认落入 App 沙盒，
//  因此默认流程不会请求相册写入权限，仅在用户主动「导出到相册」时才请求。
//

import AVFoundation
import Combine
import Foundation
import Photos
import UIKit

@MainActor
final class PermissionManager: ObservableObject {

    static let shared = PermissionManager()

    @Published private(set) var cameraStatus: AVAuthorizationStatus
    @Published private(set) var microphoneStatus: AVAuthorizationStatus

    private init() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    // MARK: - 相机

    var cameraGranted: Bool { cameraStatus == .authorized }

    func requestCameraIfNeeded() async -> Bool {
        switch cameraStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            return granted
        default:
            return false
        }
    }

    // MARK: - 麦克风

    var microphoneGranted: Bool { microphoneStatus == .authorized }

    func requestMicrophoneIfNeeded() async -> Bool {
        switch microphoneStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            return granted
        default:
            return false
        }
    }

    // MARK: - 相册（仅导出时按需请求）

    func requestPhotoLibraryAddIfNeeded() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    cont.resume(returning: status == .authorized || status == .limited)
                }
            }
        default:
            return false
        }
    }

    // MARK: - 跳转设置

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
