import AppKit
import ImageIO

final class CharacterArtwork {
    let atlas: CGImage?
    let frames: [[CGImage]]
    let isLoaded: Bool

    init(_ character: CharacterDefinition) {
        let sheet = character.sprites
        let urls = [Bundle.main.resourceURL?.appendingPathComponent(sheet.assetName),
                    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/" + sheet.assetName)]
        atlas = urls.compactMap { $0 }.compactMap { url -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }.first
        if let atlas {
            let bounds=CGRect(x:0,y:0,width:atlas.width,height:atlas.height)
            frames = sheet.frameRects.map { row in row.compactMap { rect in
                bounds.contains(rect) && rect.width>0 && rect.height>0 ? atlas.cropping(to:rect) : nil
            } }
        } else { frames = [] }
        let loadedFrames=frames
        isLoaded = loadedFrames.count == 3 && sheet.footCorrections.count == 3 && !sheet.walkFrames.isEmpty
            && loadedFrames.indices.allSatisfy { row in
                loadedFrames[row].count == sheet.frameRects[row].count && loadedFrames[row].count >= 4
                    && sheet.footCorrections[row].count == loadedFrames[row].count
                    && sheet.walkFrames.allSatisfy { loadedFrames[row].indices.contains($0) }
            }
    }
}
