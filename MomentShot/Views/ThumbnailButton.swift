//
//  ThumbnailButton.swift
//  MomentShot
//
//  左下角的"最近一条媒体"缩略图。
//  - 照片：直接读取 UIImage
//  - 视频：取首帧 (AVAssetImageGenerator)
//  - 视频角标 ▶ 叠加
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class ThumbnailLoader: ObservableObject {
    @Published var image: UIImage?

    private var loadingItemID: UUID?

    func load(item: MediaItem?) {
        guard let item else {
            image = nil
            loadingItemID = nil
            return
        }
        if loadingItemID == item.id { return }
        loadingItemID = item.id
        let url = item.absoluteURL
        let type = item.type
        let id = item.id

        DispatchQueue.global(qos: .userInitiated).async {
            let img: UIImage?
            switch type {
            case .photo:
                img = UIImage(contentsOfFile: url.path).flatMap(ThumbnailLoader.downscale)
            case .video:
                img = ThumbnailLoader.firstFrame(of: url)
            }
            DispatchQueue.main.async {
                guard self.loadingItemID == id else { return }
                self.image = img
            }
        }
    }

    nonisolated private static func firstFrame(of url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        let time = CMTime(seconds: 0.05, preferredTimescale: 600)
        if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: cg)
        }
        return nil
    }

    nonisolated private static func downscale(_ image: UIImage) -> UIImage {
        let target: CGFloat = 240
        let ratio = max(image.size.width, image.size.height) / target
        if ratio <= 1 { return image }
        let size = CGSize(width: image.size.width / ratio, height: image.size.height / ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// 取景器左下角的"最近一条媒体"缩略图（只是视觉，不带点击行为；
/// 由外层 `NavigationLink` 包裹以触发跳转到相册）。
struct ThumbnailButton: View {

    let item: MediaItem?

    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )

            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.4))
            }

            if item?.type == .video {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding(4)
                        Spacer()
                    }
                }
            }
        }
        .frame(width: 40, height: 40)
        .opacity(item == nil ? 0.4 : 1)
        .onChange(of: item?.id) { _ in loader.load(item: item) }
        .onAppear { loader.load(item: item) }
    }
}
