//
//  StorageManagementView.swift
//  MomentShot
//
//  存储管理：
//  - 概览：按类型显示数量与占用
//  - 详情：每个类型的列表，可批量勾选删除或一键清空
//

import AVFoundation
import SwiftUI
import UIKit

struct StorageManagementView: View {

    @StateObject private var index = MediaIndex.shared

    var body: some View {
        List {
            Section("沙盒占用") {
                NavigationLink {
                    StorageTypeDetailView(type: .photo)
                } label: {
                    StorageRow(
                        icon: "photo",
                        title: "照片",
                        count: index.count(of: .photo),
                        bytes: index.totalBytes(of: .photo)
                    )
                }
                NavigationLink {
                    StorageTypeDetailView(type: .video)
                } label: {
                    StorageRow(
                        icon: "video",
                        title: "视频",
                        count: index.count(of: .video),
                        bytes: index.totalBytes(of: .video)
                    )
                }
            }

            Section {
                Text("可用空间：\(formatBytes(MediaStore.availableDiskSpace()))")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
        }
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 概览行

private struct StorageRow: View {
    let icon: String
    let title: String
    let count: Int
    let bytes: Int64

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text("\(count) 项 · \(formatBytes(bytes))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 类型详情

struct StorageTypeDetailView: View {

    let type: MediaType

    @StateObject private var index = MediaIndex.shared
    @State private var isEditing = false
    @State private var selection: Set<UUID> = []
    @State private var confirmClearAll = false
    @State private var confirmDeleteSelected = false

    private var items: [MediaItem] {
        index.filtered(by: type)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(type == .photo ? "照片" : "视频")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if items.isEmpty {
                    EmptyView()
                } else {
                    Button(isEditing ? "完成" : "选择") {
                        withAnimation { isEditing.toggle() }
                        if !isEditing { selection.removeAll() }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing && !items.isEmpty {
                bottomBar
            } else if !items.isEmpty {
                clearAllBar
            }
        }
        .confirmationDialog(
            "确定要清空全部\(type == .photo ? "照片" : "视频")？",
            isPresented: $confirmClearAll,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) {
                index.removeAll(of: type)
                HapticManager.warning()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "删除已选 \(selection.count) 项？",
            isPresented: $confirmDeleteSelected,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                let toDelete = items.filter { selection.contains($0.id) }
                index.remove(items: toDelete)
                selection.removeAll()
                HapticManager.warning()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: type == .photo ? "photo" : "video")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("沙盒中没有\(type == .photo ? "照片" : "视频")")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(items) { item in
                ItemRow(
                    item: item,
                    isEditing: isEditing,
                    selected: selection.contains(item.id)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing {
                        toggleSelect(item.id)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        index.remove(id: item.id)
                        HapticManager.warning()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                if selection.count == items.count {
                    selection.removeAll()
                } else {
                    selection = Set(items.map(\.id))
                }
            } label: {
                Text(selection.count == items.count ? "取消全选" : "全选")
            }
            Spacer()
            Button(role: .destructive) {
                guard !selection.isEmpty else { return }
                confirmDeleteSelected = true
            } label: {
                Label("删除已选", systemImage: "trash")
            }
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var clearAllBar: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                confirmClearAll = true
            } label: {
                Label("清空全部", systemImage: "trash.fill")
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func toggleSelect(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

// MARK: - 列表项

private struct ItemRow: View {

    let item: MediaItem
    let isEditing: Bool
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }

            ItemThumbnail(item: item)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detailLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        parts.append("\(item.width)×\(item.height)")
        if let dur = item.duration, item.type == .video {
            parts.append(formatDuration(dur))
        }
        parts.append(formatBytes(item.fileSize))
        parts.append(shortDate(item.createdAt))
        return parts.joined(separator: " · ")
    }
}

private struct ItemThumbnail: View {
    let item: MediaItem

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.type == .photo ? "photo" : "video")
                    .foregroundColor(.secondary)
            }

            if item.type == .video {
                Image(systemName: "play.fill")
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .font(.system(size: 8, weight: .black))
            }
        }
        .onAppear { load() }
    }

    private func load() {
        let url = item.absoluteURL
        let type = item.type
        DispatchQueue.global(qos: .utility).async {
            let img: UIImage?
            switch type {
            case .photo:
                img = UIImage(contentsOfFile: url.path)
            case .video:
                img = StorageManagementVideoThumb.first(of: url)
            }
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}

private enum StorageManagementVideoThumb {
    static func first(of url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 120, height: 120)
        if let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.05, preferredTimescale: 600), actualTime: nil) {
            return UIImage(cgImage: cg)
        }
        return nil
    }
}

// MARK: - 通用格式化工具

func formatBytes(_ bytes: Int64) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    return f.string(fromByteCount: max(0, bytes))
}

func formatDuration(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    if s >= 60 { return String(format: "%d:%02d", s / 60, s % 60) }
    return "\(s)s"
}

func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MM-dd HH:mm"
    return f.string(from: date)
}
