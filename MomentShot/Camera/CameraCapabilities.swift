//
//  CameraCapabilities.swift
//  MomentShot
//
//  探测当前机型 + 镜头位置实际支持的视频分辨率与帧率。
//  通过 AVCaptureDevice.formats 与 videoSupportedFrameRateRanges 动态枚举，
//  避免在不同机型上展示不可用的固定 preset。
//

import AVFoundation
import CoreMedia
import Foundation

enum CameraCapabilities {

    /// 仅向用户暴露这三档帧率（与设备真实支持取交集）
    static let candidateFrameRates: [Int] = [30, 60, 120]

    /// 仅向用户暴露这四档分辨率（与设备真实支持取交集）
    /// 4K UHD / 1440p / 1080p / 720p
    static let candidateResolutions: [VideoResolution] = [
        VideoResolution(width: 3840, height: 2160),
        VideoResolution(width: 1920, height: 1440),
        VideoResolution(width: 1920, height: 1080),
        VideoResolution(width: 1280, height: 720)
    ]

    /// 找到指定镜头位置的最优 AVCaptureDevice（与 CameraService 选择策略一致）
    static func device(for position: CameraPosition) -> AVCaptureDevice? {
        let avPos: AVCaptureDevice.Position = (position == .front) ? .front : .back
        let types: [AVCaptureDevice.DeviceType]
        if #available(iOS 15.4, *) {
            types = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
        } else {
            types = [
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: avPos
        )
        return session.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPos)
    }

    /// 当前镜头实际支持的视频分辨率（仅在白名单 4K / 1080p / 720p 内取交集），按像素从大到小排序
    static func supportedResolutions(for position: CameraPosition) -> [VideoResolution] {
        guard let device = device(for: position) else { return [] }
        var deviceSet = Set<String>()
        for format in device.formats {
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            deviceSet.insert(VideoResolution(width: Int(dim.width), height: Int(dim.height)).id)
        }
        return candidateResolutions
            .filter { deviceSet.contains($0.id) }
            .sorted { $0.pixels > $1.pixels }
    }

    /// 指定镜头 + 指定分辨率下，设备真实支持的帧率（仅在白名单 30 / 60 / 120 内取交集）
    static func supportedFrameRates(
        for position: CameraPosition,
        resolution: VideoResolution
    ) -> [VideoFrameRate] {
        guard let device = device(for: position) else { return [] }

        var maxFPS: Double = 0
        for format in device.formats {
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard Int(dim.width) == resolution.width,
                  Int(dim.height) == resolution.height else { continue }
            for range in format.videoSupportedFrameRateRanges where range.maxFrameRate > maxFPS {
                maxFPS = range.maxFrameRate
            }
        }

        guard maxFPS > 0 else { return [] }

        return candidateFrameRates
            .filter { Double($0) <= maxFPS }
            .map { VideoFrameRate(fps: $0) }
    }

    /// 在 device.formats 中挑选与目标 (w, h, fps) 最匹配的 AVCaptureDevice.Format
    static func bestFormat(
        for device: AVCaptureDevice,
        targetWidth: Int,
        targetHeight: Int,
        targetFPS: Int
    ) -> AVCaptureDevice.Format? {
        // 第一轮：完全命中分辨率 + 帧率落在 range 内
        for format in device.formats {
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard Int(dim.width) == targetWidth, Int(dim.height) == targetHeight else { continue }
            let supports = format.videoSupportedFrameRateRanges.contains { range in
                Double(targetFPS) >= range.minFrameRate && Double(targetFPS) <= range.maxFrameRate
            }
            if supports { return format }
        }
        // 第二轮：仅命中分辨率，帧率失败时取第一个
        for format in device.formats {
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if Int(dim.width) == targetWidth && Int(dim.height) == targetHeight {
                return format
            }
        }
        return nil
    }
}
