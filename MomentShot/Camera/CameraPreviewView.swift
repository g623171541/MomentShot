//
//  CameraPreviewView.swift
//  MomentShot
//
//  把 AVCaptureVideoPreviewLayer 包成 SwiftUI 视图。
//  同时提供单击/长按/双击/双指缩放手势，暴露 location 给 SwiftUI。
//

import AVFoundation
import SwiftUI
import UIKit

final class PreviewBackingView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    var onSingleTap: ((CGPoint) -> Void)?
    var onDoubleTap: (() -> Void)?
    var onLongPress: ((CGPoint) -> Void)?
    var onPinch: ((_ scale: CGFloat, _ state: UIGestureRecognizer.State) -> Void)?

    private lazy var singleTap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        g.numberOfTapsRequired = 1
        return g
    }()

    private lazy var doubleTap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        g.numberOfTapsRequired = 2
        return g
    }()

    private lazy var longPress: UILongPressGestureRecognizer = {
        let g = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        g.minimumPressDuration = 1.0
        g.allowableMovement = 12
        return g
    }()

    private lazy var pinch: UIPinchGestureRecognizer = {
        UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    }()

    func installGestures() {
        // 让单击等待双击失败，避免误触
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
        addGestureRecognizer(doubleTap)
        addGestureRecognizer(longPress)
        addGestureRecognizer(pinch)
    }

    @objc private func handleSingleTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: self)
        onSingleTap?(p)
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        onDoubleTap?()
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        if g.state == .began {
            let p = g.location(in: self)
            onLongPress?(p)
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        onPinch?(g.scale, g.state)
        if g.state == .ended || g.state == .cancelled || g.state == .failed {
            g.scale = 1.0
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession
    var onViewReady: ((PreviewBackingView) -> Void)?

    func makeUIView(context: Context) -> PreviewBackingView {
        let view = PreviewBackingView()
        view.backgroundColor = .black
        view.videoLayer.session = session
        view.videoLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        view.installGestures()
        DispatchQueue.main.async {
            onViewReady?(view)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewBackingView, context: Context) {
        if uiView.videoLayer.session !== session {
            uiView.videoLayer.session = session
        }
    }
}
