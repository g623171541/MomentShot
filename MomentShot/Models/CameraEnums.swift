//
//  CameraEnums.swift
//  MomentShot
//
//  各类枚举：闪光灯/定时器/长按行为/视频分辨率/帧率 等。
//

import Foundation

enum FlashMode: String, CaseIterable, Identifiable {
    case auto
    case on
    case off
    case torch

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .auto:  return "bolt.badge.a.fill"
        case .on:    return "bolt.fill"
        case .off:   return "bolt.slash.fill"
        case .torch: return "flashlight.on.fill"
        }
    }

    var displayLabel: String {
        switch self {
        case .auto:  return "自动"
        case .on:    return "开"
        case .off:   return "关"
        case .torch: return "手电"
        }
    }

    func next() -> FlashMode {
        switch self {
        case .auto:  return .on
        case .on:    return .off
        case .off:   return .torch
        case .torch: return .auto
        }
    }
}

enum CountdownMode: Int, CaseIterable, Identifiable {
    case off = 0
    case three = 3
    case ten = 10

    var id: Int { rawValue }

    var displayLabel: String {
        switch self {
        case .off:   return "关"
        case .three: return "3s"
        case .ten:   return "10s"
        }
    }

    func next() -> CountdownMode {
        switch self {
        case .off:   return .three
        case .three: return .ten
        case .ten:   return .off
        }
    }
}

enum LongPressBehavior: String, CaseIterable, Identifiable {
    case recordVideo
    case burst

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .recordVideo: return "录制视频"
        case .burst:       return "高速连拍"
        }
    }
}

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

enum VideoResolution: String, CaseIterable, Identifiable {
    case hd720
    case hd1080
    case uhd4k

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .hd720:  return "720p"
        case .hd1080: return "1080p"
        case .uhd4k:  return "4K"
        }
    }
}

enum VideoFrameRate: Int, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }

    var displayLabel: String { "\(rawValue)fps" }
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
