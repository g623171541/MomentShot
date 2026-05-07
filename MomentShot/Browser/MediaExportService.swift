//
//  MediaExportService.swift
//  MomentShot
//
//  仅在用户主动点击"导出到相册"时调用：
//  - 按需申请相册写入权限（addOnly）
//  - 将沙盒中的照片/视频拷贝到系统相册
//

import Foundation
import Photos
import UIKit

enum MediaExportError: LocalizedError {
    case permissionDenied
    case exportFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得相册写入权限，请在『设置』中开启。"
        case .exportFailed(let err):
            return "导出失败：\(err.localizedDescription)"
        }
    }
}

@MainActor
enum MediaExportService {

    /// 将单条沙盒媒体导出到系统相册。
    /// 调用方应捕获错误并提示用户。
    static func saveToPhotoLibrary(_ item: MediaItem) async throws {
        let granted = await PermissionManager.shared.requestPhotoLibraryAddIfNeeded()
        guard granted else { throw MediaExportError.permissionDenied }

        let url = item.absoluteURL
        let type = item.type

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let resourceType: PHAssetResourceType = (type == .photo) ? .photo : .video
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: resourceType, fileURL: url, options: options)
            }
        } catch {
            throw MediaExportError.exportFailed(underlying: error)
        }
    }
}
