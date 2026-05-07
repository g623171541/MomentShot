//
//  MediaPageContent.swift
//  MomentShot
//
//  浏览器单页内容：
//  - PhotoPageContent 展示静态照片（异步加载，避免主线程读盘）
//  - VideoPageContent 自动静音循环播放
//

import AVKit
import Combine
import SwiftUI
import UIKit

// MARK: - PhotoPageContent

struct PhotoPageContent: View {
    let item: MediaItem

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .onAppear { load() }
        .onChange(of: item.id) { _ in
            image = nil
            load()
        }
    }

    private func load() {
        let url = item.absoluteURL
        DispatchQueue.global(qos: .userInitiated).async {
            let img = UIImage(contentsOfFile: url.path)
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}

// MARK: - VideoPageContent

struct VideoPageContent: View {

    let item: MediaItem
    let isActive: Bool

    @StateObject private var player = LoopingPlayer()

    var body: some View {
        ZStack {
            if let avPlayer = player.player {
                LoopingVideoView(player: avPlayer)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .onAppear {
            player.load(url: item.absoluteURL)
            if isActive { player.play() }
        }
        .onDisappear {
            player.stop()
        }
        .onChange(of: isActive) { newValue in
            if newValue { player.play() } else { player.pause() }
        }
        .onChange(of: item.id) { _ in
            player.load(url: item.absoluteURL)
            if isActive { player.play() }
        }
    }
}

// MARK: - LoopingPlayer

@MainActor
final class LoopingPlayer: ObservableObject {

    @Published private(set) var player: AVPlayer?

    private var endObserver: NSObjectProtocol?
    private var currentURL: URL?

    func load(url: URL) {
        if currentURL == url, player != nil { return }
        currentURL = url

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.actionAtItemEnd = .none
        player = p

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player = nil
        currentURL = nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - LoopingVideoView (UIView wrapper for AVPlayerLayer，避免 VideoPlayer 自带 UI)

struct LoopingVideoView: UIViewRepresentable {

    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
