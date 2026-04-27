//
//  MediaIndex.swift
//  MomentShot
//
//  本地 JSON 索引：维护所有沙盒媒体的元数据，避免每次扫描磁盘。
//  ObservableObject — UI 可直接订阅 items 变化（如缩略图、浏览器、设置中的占用统计）。
//

import Combine
import Foundation

@MainActor
final class MediaIndex: ObservableObject {

    static let shared = MediaIndex()

    @Published private(set) var items: [MediaItem] = []

    private let ioQueue = DispatchQueue(label: "com.paddy.MomentShot.mediaIndex.io", qos: .utility)

    private init() {
        load()
    }

    // MARK: - 公开 API

    func add(_ item: MediaItem) {
        var newList = items
        newList.insert(item, at: 0)
        items = sorted(newList)
        persist()
    }

    func remove(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        MediaStore.delete(item: item)
        items.removeAll { $0.id == id }
        persist()
    }

    func remove(items toRemove: [MediaItem]) {
        let ids = Set(toRemove.map(\.id))
        for item in toRemove {
            MediaStore.delete(item: item)
        }
        items.removeAll { ids.contains($0.id) }
        persist()
    }

    func removeAll(of type: MediaType) {
        let toRemove = items.filter { $0.type == type }
        for item in toRemove {
            MediaStore.delete(item: item)
        }
        items.removeAll { $0.type == type }
        persist()
    }

    var latest: MediaItem? { items.first }

    func filtered(by type: MediaType?) -> [MediaItem] {
        guard let type else { return items }
        return items.filter { $0.type == type }
    }

    func count(of type: MediaType) -> Int {
        items.lazy.filter { $0.type == type }.count
    }

    func totalBytes(of type: MediaType) -> Int64 {
        items.lazy.filter { $0.type == type }.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 持久化

    private func sorted(_ list: [MediaItem]) -> [MediaItem] {
        list.sorted { $0.createdAt > $1.createdAt }
    }

    private func load() {
        MediaStore.bootstrap()
        let url = MediaStore.indexURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([MediaItem].self, from: data)
            items = sorted(decoded.filter { item in
                FileManager.default.fileExists(atPath: item.absoluteURL.path)
            })
            if items.count != decoded.count {
                persist()
            }
        } catch {
            items = []
        }
    }

    private func persist() {
        let snapshot = items
        ioQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                MediaStore.bootstrap()
                let data = try encoder.encode(snapshot)
                try data.write(to: MediaStore.indexURL, options: .atomic)
            } catch {
                NSLog("[MediaIndex] persist failed: \(error.localizedDescription)")
            }
        }
    }
}
