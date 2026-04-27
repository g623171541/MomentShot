//
//  MediaItem.swift
//  MomentShot
//
//  本地索引中表示一条媒体记录的数据模型。
//  仅在 App 沙盒内部维护，不与系统相册同步。
//

import Foundation

enum MediaType: String, Codable, CaseIterable, Hashable {
    case photo
    case video
}

nonisolated struct MediaItem: Codable, Identifiable, Hashable {
    let id: UUID
    let type: MediaType

    let fileName: String
    let relativePath: String

    let createdAt: Date

    var width: Int
    var height: Int
    var fileSize: Int64

    var duration: Double?

    init(
        id: UUID = UUID(),
        type: MediaType,
        fileName: String,
        relativePath: String,
        createdAt: Date = Date(),
        width: Int,
        height: Int,
        fileSize: Int64,
        duration: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.relativePath = relativePath
        self.createdAt = createdAt
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.duration = duration
    }
}

extension MediaItem {
    nonisolated var absoluteURL: URL {
        MediaStore.documentsURL.appendingPathComponent(relativePath, isDirectory: false)
    }
}
