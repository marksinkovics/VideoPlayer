import Foundation
import MetalKit
import AVKit

#if os(macOS)
import CoreVideo
#endif

class RenderController: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var view: MTKView!


    let streamURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!

    let playerItemVideoOutput = AVPlayerItemVideoOutput()

    #if os(macOS)
    var displayLink: CVDisplayLink!
    #elseif os(iOS)
    var displayLink: CADisplayLink!
    #endif

    var statusObserver: NSKeyValueObservation!
    var player: AVPlayer!
    var currentFrame: CIImage!
    var context: CIContext!

    override init() {
        super.init()

        #if os(macOS)
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
        let displayLinkContext = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(displayLink, RenderController.displayLinkFired, displayLinkContext)
        CVDisplayLinkStart(displayLink)
        #elseif os(iOS)
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(link:)))
        #endif

        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        view = MTKView()
        view.device = device

        //This will ensure that it will only redraw when we explicitly tell it to redraw using a .draw() method in our delegate
        view.isPaused = true
        view.enableSetNeedsDisplay = false

        // By setting framebufferOnly to false you are telling the view that you will be writing to it multiple times and may also read from it.
        view.framebufferOnly = false
        view.delegate = self

        context = CIContext(mtlDevice: device)

        //create a player
        let videoItem = AVPlayerItem(url: streamURL)
        self.player = AVPlayer(playerItem: videoItem)

        self.statusObserver = videoItem.observe(\.status, options: [.new, .old], changeHandler: { playerItem, change in
            if playerItem.status == .readyToPlay {
                playerItem.add(self.playerItemVideoOutput)
                #if  os(iOS)
                self.displayLink.add(to: .main, forMode: .common)
                #endif
                self.player?.play()
            }
        })
    }

    #if os(macOS)
    @objc static let displayLinkFired: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext in
        let controller = unsafeBitCast(displayLinkContext, to: RenderController.self)
        let time: CMTime = controller.playerItemVideoOutput.itemTime(for: inOutputTime.pointee)
        DispatchQueue.main.async {
            controller.update(currentTime: time)
        }
        return kCVReturnSuccess
    }
    #elseif os(iOS)
    @objc func displayLinkFired(link: CADisplayLink) {
        let currentTime = playerItemVideoOutput.itemTime(forHostTime: CACurrentMediaTime())
        update(currentTime: currentTime)
    }
    #endif

    func update(currentTime: CMTime) {
        if playerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime) {
            if let buffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
                let frameImage = CIImage(cvImageBuffer: buffer)

//                //apply pipeline of filters to ciImage
//                let pixelate = CIFilter(name: "CIPixellate")!
//                pixelate.setValue(frameImage, forKey: kCIInputImageKey)
//                pixelate.setValue(self.saturationSlider.value, forKey: kCIInputScaleKey)
//                pixelate.setValue(CIVector(x: frameImage.extent.midX, y: frameImage.extent.midY), forKey: kCIInputCenterKey)
//                self.currentFrame = pixelate.outputImage!.cropped(to: frameImage.extent)

                self.currentFrame = frameImage

                //when using metal we also need to tell it to draw
                //if we were using UIImageView we could just assign the image
                self.view.draw()
            }
        }

    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
          return
        }

        guard let ciImage = currentFrame else {
          return
        }

        guard let currentDrawable = view.currentDrawable else {
          return
        }

        let scaleX = view.drawableSize.width / ciImage.extent.width
        let scaleY = view.drawableSize.height / ciImage.extent.height

        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: min(scaleX, scaleY), y: min(scaleX, scaleY)))

        self.context?.render(scaledImage,
                             to: currentDrawable.texture,
                             commandBuffer: commandBuffer,
                             bounds: CGRect(origin: .zero, size: view.drawableSize),
                             colorSpace: CGColorSpaceCreateDeviceRGB())

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

