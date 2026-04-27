//
//  MediaStore.swift
//  MomentShot
//
//  统一管理 App 沙盒下的媒体目录、命名规则、写入与删除。
//  所有照片/视频均落入 Documents/Media/{Photos,Videos}/ 下。
//
//  整个类型由静态文件系统方法组成，全部 nonisolated。
//

import AVFoundation
import Foundation
import UIKit

enum MediaStoreError: LocalizedError {
    case insufficientDiskSpace
    case writeFailed(underlying: Error)
    case readFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .insufficientDiskSpace:
            return "存储空间不足，请清理后重试。"
        case .writeFailed(let err):
            return "写入文件失败：\(err.localizedDescription)"
        case .readFailed(let err):
            return "读取文件失败：\(err.localizedDescription)"
        }
    }
}

enum MediaStore {

    // MARK: - 目录

    nonisolated static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    nonisolated static var mediaRootURL: URL {
        documentsURL.appendingPathComponent("Media", isDirectory: true)
    }

    nonisolated static var photosURL: URL {
        mediaRootURL.appendingPathComponent("Photos", isDirectory: true)
    }

    nonisolated static var videosURL: URL {
        mediaRootURL.appendingPathComponent("Videos", isDirectory: true)
    }

    nonisolated static var indexURL: URL {
        mediaRootURL.appendingPathComponent("index.json", isDirectory: false)
    }

    nonisolated static func bootstrap() {
        let fm = FileManager.default
        for url in [mediaRootURL, photosURL, videosURL] {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - 命名

    /// 生成形如 `photo_20260427_154832123.jpg` 的文件名
    nonisolated static func makeFileName(type: MediaType, ext: String, at date: Date = Date()) -> String {
        let prefix = type == .photo ? "photo" : "video"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmssSSS"
        let stamp = formatter.string(from: date)
        return "\(prefix)_\(stamp).\(ext)"
    }

    nonisolated static func makeAbsoluteURL(for type: MediaType, fileName: String) -> URL {
        switch type {
        case .photo: return photosURL.appendingPathComponent(fileName, isDirectory: false)
        case .video: return videosURL.appendingPathComponent(fileName, isDirectory: false)
        }
    }

    nonisolated static func relativePath(for type: MediaType, fileName: String) -> String {
        switch type {
        case .photo: return "Media/Photos/\(fileName)"
        case .video: return "Media/Videos/\(fileName)"
        }
    }

    // MARK: - 写入

    @discardableResult
    nonisolated static func writePhotoData(_ data: Data, fileName: String) throws -> URL {
        bootstrap()
        try preflightDiskSpace(for: Int64(data.count))
        let url = photosURL.appendingPathComponent(fileName, isDirectory: false)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw MediaStoreError.writeFailed(underlying: error)
        }
    }

    // MARK: - 删除

    nonisolated static func delete(item: MediaItem) {
        let url = item.absoluteURL
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated static func delete(urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 文件大小

    nonisolated static func fileSize(at url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }

    // MARK: - 空间预检

    nonisolated static func availableDiskSpace() -> Int64 {
        let url = documentsURL
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }

    /// 写入前预留 50MB 空间余量
    nonisolated static func preflightDiskSpace(for needed: Int64) throws {
        let avail = availableDiskSpace()
        if avail > 0, avail < needed + 50 * 1024 * 1024 {
            throw MediaStoreError.insufficientDiskSpace
        }
    }

    // MARK: - 视频元数据

    /// 同步读取视频文件的尺寸与时长，用于写入索引。
    nonisolated static func videoMetadata(at url: URL) -> (size: CGSize, duration: Double) {
        let asset = AVURLAsset(url: url)
        let track = asset.tracks(withMediaType: .video).first
        let naturalSize = track?.naturalSize ?? .zero
        let transform = track?.preferredTransform ?? .identity
        let displaySize = naturalSize.applying(transform)
        let absSize = CGSize(width: abs(displaySize.width), height: abs(displaySize.height))
        let duration = CMTimeGetSeconds(asset.duration)
        return (absSize, duration.isFinite ? duration : 0)
    }
}
