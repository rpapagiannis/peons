import AppKit
import ImageIO
import UniformTypeIdentifiers

enum AnimationExport {
    static func write(to url: URL, character:CharacterDefinition = CharacterCatalog.defaultCharacter) {
        let count = 240, width = 800, height = 520
        guard let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, count, nil) else { return }
        CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var model = PetModel(); model.selectCharacter(character)
        model.bounds = CGRect(x: 0, y: 0, width: width, height: 450)
        model.position = CGPoint(x: 120, y: 0)
        model.size = CGSize(width: 135.68, height: 180.2)
        model.setMode(.controlled)
        model.pressKey(2)
        var dragOrigin = CGPoint.zero
        for i in 0..<count {
            if i == 25 { model.jump() }
            if i == 75 { model.releaseKey(2); model.pressKey(125) }
            if i == 90 { model.releaseKey(125) }
            if i == 105 { dragOrigin = model.position; model.beginDrag(at: Double(i) / 30) }
            if (105...116).contains(i) {
                let t = Double(i - 105) / 30
                model.drag(to: CGPoint(x: dragOrigin.x + t * 1100, y: t * 600), at: Double(i) / 30)
            }
            if i == 117 { model.endDrag(at: Double(i) / 30) }
            model.step(1.0 / 30)
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
            let ctx = graphics.cgContext; ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSColor(hex: 0x101b15).setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
            NSColor(hex: 0x36503c).setFill(); NSRect(x: 20, y: 473, width: width - 40, height: 1).fill()
            let label = i < 25 ? "WALK ALONG THE FLOOR" : i < 75 ? "JUMP HIGH" : i < 105 ? "DOWN FACES YOU" : "DRAG, THROW, BOUNCE & WRAP"
            (label as NSString).draw(at: CGPoint(x: 24, y: 21), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor(hex: 0xc9efa0)])
            let origin = model.panelOrigin
            PetRenderer.draw(in: CGRect(x: origin.x, y: 473 - origin.y - model.size.height, width: model.size.width, height: model.size.height), character:character,phase: model.phase, walking: model.isWalking, age: model.age, jump: model.jumpHeight, mode: .controlled, facing: model.facing, anticipation: CGFloat(model.jumpPreparation), landing: CGFloat(model.landingTime), dragging: model.isDragging, worldPositioned: true, frontLocked: model.frontLocked)
            NSGraphicsContext.restoreGraphicsState()
            if let image = bitmap.cgImage { CGImageDestinationAddImage(output, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 30, kCGImagePropertyGIFUnclampedDelayTime: 1.0 / 30]] as CFDictionary) }
        }
        if !CGImageDestinationFinalize(output) { fputs("Failed to export animation preview\n", stderr); exit(1) }
        print("Exported 240 frames: floor walk, high jump, front pose, throw, bounce, and edge wrap")
    }
}
