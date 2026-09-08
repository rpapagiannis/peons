import AppKit

@main enum SpeechTests {
    static func main() {
        let captions = CharacterCatalog.all.flatMap { $0.lines }
        precondition(!captions.isEmpty, "Speech coverage must include the shipped dialogue")
        var failures: [String] = []
        for scale: CGFloat in [1, 2] {
            for caption in captions {
                let rect = CGRect(origin: .zero, size: PetModel.desktopSize)
                let actual = render(size: rect.size, scale: scale) {
                    PetRenderer.drawSpeech(caption.text, in: rect)
                }
                let reference = render(size: rect.size, scale: scale) {
                    drawUnclippedReference(caption.text, in: rect)
                }
                let expectedGlyphs = glyphPixels(in: reference)
                precondition(!expectedGlyphs.isEmpty, "The reference must render visible text")
                let actualGlyphs = glyphPixels(in: actual)
                if actualGlyphs != expectedGlyphs {
                    failures.append("\(caption.id) at \(Int(scale))x: \(expectedGlyphs.subtracting(actualGlyphs).count) missing glyph pixels")
                }
            }
        }
        precondition(failures.isEmpty, "Speech differs from a complete, unclipped text layout:\n" + failures.joined(separator: "\n"))
        print("Verified all \(captions.count) shipped captions against complete glyph renders at the desktop size, at 1x and 2x")
    }

    static func render(size: CGSize, scale: CGFloat, draw: () -> Void) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: Int(ceil(size.width * scale)),
                                      pixelsHigh: Int(ceil(size.height * scale)),
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        // PetView has a top-left origin; text layout must see the same flipped state.
        NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
        context.scaleBy(x: scale, y: -scale)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    static func drawUnclippedReference(_ text: String, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor(hex: 0xe6f4db),
            .paragraphStyle: paragraph
        ]
        // Preserve the bubble's horizontal alignment, but give the reference all remaining
        // canvas height. It must render every glyph independently of the bubble's text height.
        let measured = (text as NSString).boundingRect(
            with: NSSize(width: rect.width - 28, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
        let width = ceil(measured.width)
        let referenceRect = NSRect(x: rect.midX - width / 2, y: 12,
                                   width: width, height: rect.height - 12)
        precondition(measured.height + 12 < rect.height, "Reference canvas must fit the entire caption")
        NSColor(hex: 0x19271e).setFill()
        rect.fill()
        (text as NSString).draw(with: referenceRect,
                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                               attributes: attributes)
    }

    static func glyphPixels(in bitmap: NSBitmapImageRep) -> Set<Int> {
        var pixels = Set<Int>()
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = bitmap.colorAt(x: x, y: y)!
                // Only light caption ink: the dark bubble, transparent canvas, and shadow
                // cannot satisfy this threshold. Equal masks include the final wrapped line.
                if color.alphaComponent > 0.5 && color.redComponent > 0.4 && color.greenComponent > 0.45 {
                    pixels.insert(y * bitmap.pixelsWide + x)
                }
            }
        }
        return pixels
    }
}
