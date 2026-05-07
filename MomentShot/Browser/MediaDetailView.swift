//
//  MediaDetailView.swift
//  MomentShot
//
//  大图详情（由 MediaLibraryView 通过 NavigationLink 推入）：
//  - TabView 横向分页：左右滑动切换上一张 / 下一张
//  - 底栏：保存 / 删除
//  - 删除空后自动 pop 返回列表
//

import SwiftUI
import UIKit

struct MediaDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var index = MediaIndex.shared

    let mediaType: MediaType?
    @State private var selectedID: UUID

    @State private var toast: ToastInfo?
    @State private var isExporting = false
    @State private var showDeleteConfirmation = false

    init(mediaType: MediaType?, initialID: UUID) {
        self.mediaType = mediaType
        _selectedID = State(initialValue: initialID)
    }

    private var items: [MediaItem] {
        index.filtered(by: mediaType)
    }

    private var currentItem: MediaItem? {
        items.first(where: { $0.id == selectedID }) ?? items.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                Color.black.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    pager
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !items.isEmpty {
                HStack {
                    Spacer(minLength: 0)
                    bottomBar
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 0)
            }

            if let toast {
                ToastView(info: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavBackButton { dismiss() }
            }
        }
        .onChange(of: items.map(\.id)) { newIDs in
            if newIDs.isEmpty {
                dismiss()
                return
            }
            if !newIDs.contains(selectedID) {
                selectedID = newIDs.first ?? selectedID
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteCurrent()
            }
        } message: {
            Text("删除后将无法在本应用中恢复。")
        }
    }

    // MARK: - 子视图

    private var pager: some View {
        TabView(selection: $selectedID) {
            ForEach(items) { item in
                MediaPageView(
                    item: item,
                    isActive: item.id == selectedID
                )
                .tag(item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.white.opacity(0.5))
            Text("还没有拍摄记录")
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 15) {
            BarButton(icon: "trash", label: "删除", tint: .red, disabled: isExporting) {
                showDeleteConfirmation = true
            }
            BarButton(icon: "square.and.arrow.down", label: "保存", disabled: isExporting) {
                exportToPhotoLibrary()
            }
        }
        .padding(.vertical, 0)
        .frame(width: UIScreen.main.bounds.width * 0.6)
    }

    private var titleText: String {
        currentItem?.fileName ?? ""
    }

    // MARK: - 操作

    private func deleteCurrent() {
        guard let item = currentItem else { return }
        HapticManager.warning()
        let nextID: UUID? = {
            guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return nil }
            if items.count > idx + 1 { return items[idx + 1].id }
            if idx > 0 { return items[idx - 1].id }
            return nil
        }()
        withAnimation(.spring()) {
            if let nextID { selectedID = nextID }
            index.remove(id: item.id)
        }
        showToast(text: "已删除", icon: "checkmark.circle.fill", tint: .green)
    }

    private func exportToPhotoLibrary() {
        guard let item = currentItem else { return }
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                try await MediaExportService.saveToPhotoLibrary(item)
                showToast(text: "已保存到相册", icon: "checkmark.circle.fill", tint: .green)
                HapticManager.success()
            } catch let error as MediaExportError {
                showToast(text: error.errorDescription ?? "导出失败", icon: "xmark.octagon.fill", tint: .red)
                HapticManager.warning()
            } catch {
                showToast(text: "导出失败", icon: "xmark.octagon.fill", tint: .red)
                HapticManager.warning()
            }
        }
    }

    private func showToast(text: String, icon: String, tint: Color) {
        withAnimation(.spring()) {
            toast = ToastInfo(text: text, icon: icon, tint: tint)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { toast = nil }
        }
    }

    private var safeBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - 单页

private struct MediaPageView: View {
    let item: MediaItem
    let isActive: Bool

    var body: some View {
        ZStack {
            switch item.type {
            case .photo:
                PhotoPageContent(item: item)
            case .video:
                VideoPageContent(item: item, isActive: isActive)
            }
        }
    }
}

// MARK: - 底栏按钮

private struct BarButton: View {
    /// 与半屏底栏宽度适配（约三枚并排）
    private static let circleSize: CGFloat = 65

    let icon: String
    let label: String
    var tint: Color = .white
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(tint)
            .frame(width: Self.circleSize, height: Self.circleSize)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

// MARK: - Toast

private struct ToastInfo: Equatable {
    let text: String
    let icon: String
    let tint: Color
}

private struct ToastView: View {
    let info: ToastInfo

    var body: some View {
        VStack {
            Spacer().frame(height: 100)
            HStack(spacing: 8) {
                Image(systemName: info.icon)
                    .foregroundColor(info.tint)
                Text(info.text)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            Spacer()
        }
    }
}
