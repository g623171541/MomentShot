//
//  VolumeButtonObserver.swift
//  MomentShot
//
//  通过观察 AVAudioSession.outputVolume 的 KVO 变化感知音量键按下事件。
//  - 用一个 0×0 的隐藏 MPVolumeView 让系统音量条不出现在屏幕上方（iOS 默认会弹）。
//  - 监听 outputVolume 的变化即视为按键事件。
//
//  注意：录像中 AVCaptureSession 已自行管理 audio session，
//        我们通过同一个 sharedInstance 监听 outputVolume 即可。
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
final class VolumeButtonObserver: NSObject, ObservableObject {

    /// 音量键被按下时回调。direction：true=音量+，false=音量-。
    var onPress: ((Bool) -> Void)?

    private var hiddenVolumeView: MPVolumeView?
    private var observation: NSKeyValueObservation?
    private var lastVolume: Float = 0
    private var isStarted = false

    /// 在主窗口下挂载隐藏 MPVolumeView，并启动 KVO。
    /// 多次调用安全（幂等）。
    func start() {
        guard !isStarted else { return }
        isStarted = true

        // 1) 激活 audio session（与 AVCaptureSession 共用 sharedInstance）
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            // 即便失败也尝试 KVO，多数情况下相机会话已经激活
        }
        lastVolume = AVAudioSession.sharedInstance().outputVolume

        // 2) 注入 0×0 的隐藏 MPVolumeView，抑制系统音量 HUD
        attachHiddenVolumeView()

        // 3) KVO 监听 outputVolume（KVO 闭包是 nonisolated/Sendable，必须 hop 到 main actor）
        observation = AVAudioSession.sharedInstance()
            .observe(\.outputVolume, options: [.new]) { [weak self] session, change in
                let newValue: Float = change.newValue ?? session.outputVolume
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let isUp = newValue > self.lastVolume
                    self.lastVolume = newValue
                    self.onPress?(isUp)
                }
            }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        observation?.invalidate()
        observation = nil

        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
    }

    private func attachHiddenVolumeView() {
        guard hiddenVolumeView == nil else { return }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return }

        let view = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 1, height: 1))
        view.alpha = 0.001
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        window.addSubview(view)
        hiddenVolumeView = view
    }
}
