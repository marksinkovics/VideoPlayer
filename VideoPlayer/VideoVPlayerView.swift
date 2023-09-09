import Foundation
import MetalKit
import SwiftUI

#if os(macOS)

import AppKit

struct VideoVPlayerView : NSViewRepresentable {
    typealias NSViewType = MTKView

    let renderController = RenderController()

    func makeNSView(context: Context) -> NSViewType {
        return renderController.view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {

    }
}


#elseif os(iOS)

import UIKit

struct VideoVPlayerView : UIViewRepresentable {
    typealias UIViewType = MTKView
    let renderController = RenderController()


    func makeUIView(context: Context) -> UIViewType {
        return renderController.view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {

    }
}
#endif

