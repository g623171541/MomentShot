//
//  MediaLibraryView.swift
//  MomentShot
//
//  相册主页（NavigationLink 推入）：
//  - 导航栏：左侧返回，标题「图库」，右侧编辑 / 完成
//  - 内容：分类切换（全部 / 照片 / 视频）+ 九宫格缩略图
//  - 编辑模式：点选多选、全选 / 取消全选、批量删除（二次确认）；切换分类退出编辑
//

import SwiftUI
import UIKit

struct MediaLibraryView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var index = MediaIndex.shared
    @State private var filter: BrowserFilter = .all

    @State private var isEditing = false
    @State private var selection: Set<UUID> = []
    @State private var showBatchDeleteConfirmation = false

    private var items: [MediaItem] {
        index.filtered(by: filter.mediaType)
    }

    /// 当前列表是否已全部选中（用于全选 ↔ 取消全选）
    private var isAllSelected: Bool {
        guard !items.isEmpty else { return false }
        return selection == Set(items.map(\.id))
    }

    var body: some View {
        VStack(spacing: 12) {
            FilterSegmentedView(filter: $filter)
                .padding(.horizontal, 16)

            Group {
                if items.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    gridContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEditing {
                editBottomBar
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("图库")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavBackButton { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.light()
                    if isEditing {
                        isEditing = false
                        selection.removeAll()
                    } else {
                        isEditing = true
                    }
                } label: {
                    Text(isEditing ? "完成" : "编辑")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: filter) { _ in
            isEditing = false
            selection.removeAll()
        }
        .alert("删除所选项目？", isPresented: $showBatchDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteSelected()
            }
        } message: {
            Text("将永久删除 \(selection.count) 项，且无法在本应用中恢复。")
        }
    }

    // MARK: - 子视图

    private var gridContent: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
        return ScrollView {
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(items) { item in
                    gridCell(for: item)
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func gridCell(for item: MediaItem) -> some View {
        let selected = selection.contains(item.id)
        let thumb = Color.clear
            .aspectRatio(1, contentMode: .fill)
            .overlay(MediaGridThumb(item: item))
            .clipped()
            .overlay {
                if isEditing {
                    selectionBadge(selected: selected)
                }
            }
            .contentShape(Rectangle())

        if isEditing {
            Button {
                HapticManager.light()
                toggleSelection(item.id)
            } label: {
                thumb
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                MediaDetailView(mediaType: filter.mediaType, initialID: item.id)
            } label: {
                thumb
            }
            .buttonStyle(.plain)
        }
    }

    private func selectionBadge(selected: Bool) -> some View {
        ZStack {
            Color.black.opacity(selected ? 0.35 : 0.2)
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .background(Circle().fill(selected ? Color.accentColor : Color.clear))
                            .frame(width: 24, height: 24)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                }
                Spacer()
            }
        }
    }

    private var editBottomBar: some View {
        HStack(spacing: 24) {
            Button {
                HapticManager.light()
                toggleSelectAll()
            } label: {
                Text(isAllSelected ? "取消全选" : "全选")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.warning()
                showBatchDeleteConfirmation = true
            } label: {
                Text("删除")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(selection.isEmpty)
            .opacity(selection.isEmpty ? 0.35 : 1)
        }
        .padding(.top, 14)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.white.opacity(0.5))
            Text(filter == .all ? "还没有拍摄记录" : "暂无该类型的内容")
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - 选择 / 删除

    private func toggleSelection(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// 未全选时选中当前列表全部；已全部选中时清空选择。
    private func toggleSelectAll() {
        let visible = Set(items.map(\.id))
        guard !visible.isEmpty else { return }
        if selection == visible {
            selection.removeAll()
        } else {
            selection = visible
        }
    }

    private func deleteSelected() {
        let toRemove = items.filter { selection.contains($0.id) }
        guard !toRemove.isEmpty else { return }
        HapticManager.warning()
        index.remove(items: toRemove)
        selection.removeAll()
        if items.isEmpty {
            isEditing = false
        }
    }
}

// MARK: - 分类

enum BrowserFilter: String, CaseIterable, Identifiable {
    case all, photo, video

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:   return "全部"
        case .photo: return "照片"
        case .video: return "视频"
        }
    }

    var mediaType: MediaType? {
        switch self {
        case .all:   return nil
        case .photo: return .photo
        case .video: return .video
        }
    }
}

struct FilterSegmentedView: View {
    @Binding var filter: BrowserFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BrowserFilter.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        filter = option
                    }
                    HapticManager.light()
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .foregroundColor(filter == option ? .black : .white)
                        .background(
                            ZStack {
                                if filter == option {
                                    Capsule().fill(Color.white)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }
}
