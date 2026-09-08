import CoreGraphics

// A single world canvas is painted through one clipped native window per display.
// This also works when macOS gives every monitor its own Space.
struct CanvasSlice {
    let windowFrame: CGRect
    let drawingRect: CGRect

    init(canvas: CGRect, windowFrame: CGRect) {
        self.windowFrame = windowFrame
        drawingRect = CGRect(x:canvas.minX-windowFrame.minX,
                             y:windowFrame.maxY-canvas.maxY,
                             width:canvas.width,height:canvas.height)
    }
    static func visible(canvas: CGRect, display: CGRect) -> CanvasSlice? {
        let overlap = canvas.intersection(display)
        guard !overlap.isNull, overlap.width>0, overlap.height>0 else { return nil }
        return CanvasSlice(canvas:canvas,windowFrame:overlap)
    }
    func canvasPoint(from local: CGPoint) -> CGPoint {
        CGPoint(x:(local.x-drawingRect.minX)/drawingRect.width*256,
                y:(local.y-drawingRect.minY)/drawingRect.height*340)
    }
}
