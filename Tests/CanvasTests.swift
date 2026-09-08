import Foundation
import CoreGraphics

@main enum CanvasTests {
    static func main() {
        let canvas=CGRect(x:900,y:100,width:256,height:340)
        let left=CanvasSlice.visible(canvas:canvas,display:CGRect(x:0,y:0,width:1000,height:800))!
        let right=CanvasSlice.visible(canvas:canvas,display:CGRect(x:1000,y:0,width:1000,height:800))!
        precondition(left.windowFrame.maxX==right.windowFrame.minX)
        precondition(left.windowFrame.width+right.windowFrame.width==canvas.width)
        precondition(left.canvasPoint(from:CGPoint(x:100,y:170))==right.canvasPoint(from:CGPoint(x:0,y:170)))
        let vertical=CGRect(x:50,y:700,width:256,height:340)
        let bottom=CanvasSlice.visible(canvas:vertical,display:CGRect(x:0,y:0,width:1000,height:800))!
        let top=CanvasSlice.visible(canvas:vertical,display:CGRect(x:0,y:800,width:1000,height:800))!
        precondition(bottom.windowFrame.height+top.windowFrame.height==vertical.height)
        precondition(bottom.canvasPoint(from:CGPoint(x:128,y:0))==top.canvasPoint(from:CGPoint(x:128,y:240)))
        precondition(CanvasSlice.visible(canvas:canvas,display:CGRect(x:-1000,y:0,width:1000,height:800))==nil)
        let single=CanvasSlice.visible(canvas:canvas,display:CGRect(x:0,y:0,width:2000,height:1000))!
        precondition(single.drawingRect==CGRect(origin:.zero,size:canvas.size))
        print("Passed canvas slicing: horizontal and vertical seams preserve drawing and hit coordinates; absent displays and single-display bounds.")
    }
}
