//
//  SettingsContentView.swift
//  MomentShot
//
//  设置页（由取景器 NavigationLink 横向推入）：
//  - 拍摄参数（动态分辨率/帧率）
//  - 音量键
//  - 显示辅助
//  - 反馈
//  - 存储管理
//

import SwiftUI

struct SettingsContentView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    let cameraPosition: CameraPosition

    private var supportedResolutions: [VideoResolution] {
        CameraCapabilities.supportedResolutions(for: cameraPosition)
    }

    private var supportedFrameRates: [VideoFrameRate] {
        CameraCapabilities.supportedFrameRates(
            for: cameraPosition,
            resolution: effectiveResolution
        )
    }

    private var effectiveResolution: VideoResolution {
        if supportedResolutions.contains(settings.videoResolution) {
            return settings.videoResolution
        }
        return supportedResolutions.first ?? settings.videoResolution
    }

    private var effectiveFrameRate: VideoFrameRate {
        if supportedFrameRates.contains(settings.videoFrameRate) {
            return settings.videoFrameRate
        }
        return supportedFrameRates.last ?? settings.videoFrameRate
    }

    private var resolutionBinding: Binding<VideoResolution> {
        Binding(
            get: { effectiveResolution },
            set: { newValue in
                settings.videoResolution = newValue
                let fps = CameraCapabilities.supportedFrameRates(for: cameraPosition, resolution: newValue)
                if !fps.contains(settings.videoFrameRate), let fallback = fps.last {
                    settings.videoFrameRate = fallback
                }
            }
        )
    }

    private var frameRateBinding: Binding<VideoFrameRate> {
        Binding(
            get: { effectiveFrameRate },
            set: { settings.videoFrameRate = $0 }
        )
    }

    var body: some View {
        List {
            Section {
                Picker("视频分辨率", selection: resolutionBinding) {
                    ForEach(supportedResolutions) { Text($0.displayLabel).tag($0) }
                }
                Picker("视频帧率", selection: frameRateBinding) {
                    ForEach(supportedFrameRates) { Text($0.displayLabel).tag($0) }
                }
                Picker("照片质量", selection: $settings.photoResolution) {
                    ForEach(PhotoResolution.allCases) { Text($0.displayLabel).tag($0) }
                }
            } header: {
                Text("拍摄参数")
            } footer: {
                Text("仅展示当前\(cameraPosition == .front ? "前置" : "后置")摄像头支持的分辨率与帧率。")
                    .font(.footnote)
            }

            Section {
                Picker("音量键功能", selection: $settings.volumeButtonAction) {
                    ForEach(VolumeButtonAction.allCases) { Text($0.displayLabel).tag($0) }
                }
            } header: {
                Text("音量键")
            } footer: {
                Text("通过音量上 / 下键即可触发；选「禁用」时音量键恢复系统默认行为。")
                    .font(.footnote)
            }

            Section("显示辅助") {
                Toggle("双击空白切换镜头", isOn: $settings.enableDoubleTapFlip)
                Toggle("单指变焦条", isOn: $settings.enableSingleFingerZoom)
            }

            Section("反馈") {
                Toggle("触觉反馈", isOn: $settings.hapticEnabled)
                Toggle("静音拍摄（需符合地区法规）", isOn: $settings.silentShutter)
            }

            Section("存储管理") {
                NavigationLink {
                    StorageManagementView()
                } label: {
                    Label("查看与清理", systemImage: "internaldrive")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavBackButton(tint: Color.primary) { dismiss() }
            }
        }
    }
}
