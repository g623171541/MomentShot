//
//  MediaGridThumb.swift
//  MomentShot
//
//  浏览器九宫格里的单个缩略图：
//  - 照片：UIImage 解码 + 降采样
//  - 视频：AVAssetImageGenerator 取首帧 + 时长角标
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct MediaGridThumb: View {

    let item: MediaItem

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(0.06)

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Image(systemName: item.type == .photo ? "photo" : "video")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.system(size: 18))
                }

                if item.type == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .black))
                                if let dur = item.duration {
                                    Text(formatDuration(dur))
                                        .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .padding(4)
                        }
                    }
                }
            }
        }
        .clipped()
        .onAppear { load() }
        .onChange(of: item.id) { _ in
            image = nil
            load()
        }
    }

    private func load() {
        let url = item.absoluteURL
        let type = item.type
        let id = item.id

        DispatchQueue.global(qos: .userInitiated).async {
            let img: UIImage?
            switch type {
            case .photo:
                img = UIImage(contentsOfFile: url.path)
                    .flatMap(MediaGridThumb.downscale)
            case .video:
                img = MediaGridThumb.firstFrame(of: url)
            }
            DispatchQueue.main.async {
                guard self.item.id == id else { return }
                self.image = img
            }
        }
    }

    nonisolated private static func firstFrame(of url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 360, height: 360)
        let time = CMTime(seconds: 0.05, preferredTimescale: 600)
        if let cg = try? gen.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: cg)
        }
        return nil
    }

    nonisolated private static func downscale(_ image: UIImage) -> UIImage {
        let target: CGFloat = 360
        let ratio = max(image.size.width, image.size.height) / target
        if ratio <= 1 { return image }
        let size = CGSize(width: image.size.width / ratio, height: image.size.height / ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
