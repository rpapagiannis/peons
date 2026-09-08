import AppKit

@main
enum ArtworkTests {
    static func main() {
        guard CharacterCatalog.all.allSatisfy({ PetRenderer.hasArtwork(for:$0) }) else {fatalError("Directional artwork did not load")}
        var count=0
        for row in CharacterCatalog.all.flatMap({ PetRenderer.art(for:$0).frames }) {
            for frame in row {
                var pixels=[UInt8](repeating:0,count:125*160*4)
                pixels.withUnsafeMutableBytes { bytes in
                    let ctx=CGContext(data:bytes.baseAddress,width:125,height:160,bitsPerComponent:8,bytesPerRow:500,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                    ctx.draw(frame,in:CGRect(x:0,y:0,width:125,height:160))
                }
                var transparent=0,visible=0,cyan=0
                for p in stride(from:0,to:pixels.count,by:4) {
                    if pixels[p+3]==0 {transparent += 1}
                    else {
                        visible += 1
                        if pixels[p]<60 && pixels[p+1]>145 && pixels[p+2]>185 {cyan += 1}
                    }
                }
                guard transparent>5000 && visible>2000 else {fatalError("Invalid sprite alpha or empty crop")}
                guard cyan==0 else {fatalError("Cyan atlas border leaked into a frame")}
                count += 1
            }
        }
        precondition(count > 0,"The shipped character must have directional frames")
        print("Verified all \(count) shipped directional frames: artwork, transparency, and no atlas gutters")
        for facing in [PetFacing.front, .left, .right, .back] {
            for pose in 0..<4 {
                let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:256,pixelsHigh:340,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
                let graphics=NSGraphicsContext(bitmapImageRep:bitmap)!
                NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=graphics
                let context=graphics.cgContext;context.translateBy(x:0,y:340);context.scaleBy(x:1,y:-1)
                PetRenderer.draw(in:CGRect(x:0,y:0,width:256,height:340),phase:CGFloat(pose)*Double.pi/2,walking:true,age:0,reducedMotion:true,facing:facing,worldPositioned:true)
                NSGraphicsContext.restoreGraphicsState()
                var bottom=0
                for y in 0..<340 { for x in 0..<256 {
                    if let color=bitmap.colorAt(x:x,y:y),color.alphaComponent>0.5 { bottom=max(bottom,y) }
                } }
                guard abs(CGFloat(bottom+1)-PetModel.canvasFootY)<0.1 else {
                    fatalError("\(facing.rawValue) pose \(pose) feet cross or float above the physical floor: \(bottom)")
                }
            }
        }
        print("Verified 16 rendered poses, including mirrored right: feet meet the physical floor without clipping")
    }
}
