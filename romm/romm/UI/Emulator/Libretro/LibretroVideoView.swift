import UIKit
import CoreGraphics

/// Naive Software-Blit-View: nimmt rohe libretro-Frames entgegen und rendert
/// sie als `CGImage` in ein `CALayer.contents`. Reicht für PCSX ReARMed
/// Bring-Up. Wird später durch eine Metal-Pipeline ersetzt.
final class LibretroVideoView: UIView, LibretroVideoSink {

    override class var layerClass: AnyClass { CALayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.magnificationFilter = .nearest
        layer.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func libretroDidProduceFrame(
        data: UnsafeRawPointer?,
        width: UInt32,
        height: UInt32,
        pitch: Int,
        pixelFormat: LibretroABI.PixelFormat
    ) {
        guard let data = data, width > 0, height > 0 else { return }

        let bitmapInfo: CGBitmapInfo
        let bitsPerComponent: Int
        let bitsPerPixel: Int

        switch pixelFormat {
        case .rgb565:
            bitmapInfo = CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue)
            bitsPerComponent = 5
            bitsPerPixel = 16
        case .xrgb8888:
            bitmapInfo = CGBitmapInfo(rawValue:
                CGImageAlphaInfo.noneSkipFirst.rawValue |
                CGImageByteOrderInfo.order32Little.rawValue
            )
            bitsPerComponent = 8
            bitsPerPixel = 32
        case .rgb1555:
            bitmapInfo = CGBitmapInfo(rawValue:
                CGImageAlphaInfo.noneSkipFirst.rawValue |
                CGImageByteOrderInfo.order16Little.rawValue
            )
            bitsPerComponent = 5
            bitsPerPixel = 16
        }

        let bytesTotal = pitch * Int(height)
        guard let provider = CGDataProvider(
            dataInfo: nil,
            data: data,
            size: bytesTotal,
            releaseData: { _, _, _ in }
        ) else { return }

        guard let image = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: pitch,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return }

        layer.contents = image
    }
}
