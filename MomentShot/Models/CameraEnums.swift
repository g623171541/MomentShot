//
//  CameraEnums.swift
//  MomentShot
//
//  各类枚举：视频分辨率 / 帧率 / 音量键行为 等。
//

import Foundation

enum VolumeButtonAction: String, CaseIterable, Identifiable {
    case takePhoto
    case toggleRecording
    case zoom
    case disabled

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .takePhoto:       return "拍照"
        case .toggleRecording: return "录像开始/停止"
        case .zoom:            return "变焦"
        case .disabled:        return "禁用"
        }
    }
}

/// 视频分辨率：按当前镜头实际支持的 (width × height) 动态枚举。
struct VideoResolution: Hashable, Identifiable {
    let width: Int
    let height: Int

    var id: String { "\(width)x\(height)" }

    var pixels: Int { width * height }

    var displayLabel: String {
        switch (width, height) {
        case (3840, 2160): return "4K"
        case (1920, 1080): return "1080p"
        case (1280, 720):  return "720p"
        case (1920, 1440): return "1440p"
        default:           return "\(width)×\(height)"
        }
    }

    static let `default` = VideoResolution(width: 1920, height: 1080)
}

/// 视频帧率：根据当前 (镜头 + 分辨率) 实际支持的整数帧率动态枚举。
struct VideoFrameRate: Hashable, Identifiable {
    let fps: Int

    var id: Int { fps }

    var displayLabel: String { "\(fps)fps" }

    static let `default` = VideoFrameRate(fps: 30)
}

enum PhotoResolution: String, CaseIterable, Identifiable {
    case standard
    case high
    case max

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .standard: return "标准"
        case .high:     return "高"
        case .max:      return "最大"
        }
    }
}

enum CameraPosition: String, CaseIterable, Identifiable {
    case back
    case front

    var id: String { rawValue }
}
