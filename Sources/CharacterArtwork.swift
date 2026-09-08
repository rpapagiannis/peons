import AppKit
import ImageIO

final class CharacterArtwork {
    let atlas: CGImage?
    let frames: [[CGImage]]
    var isLoaded: Bool { frames.count == 3 && frames.allSatisfy { $0.count == 4 } }

    init(_ character: CharacterDefinition) {
        let sheet = character.sprites
        let urls = [Bundle.main.resourceURL?.appendingPathComponent(sheet.assetName),
                    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/" + sheet.assetName)]
        atlas = urls.compactMap { $0 }.compactMap { url -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }.first
        if let atlas {
            frames = sheet.rows.map { y in sheet.columns.compactMap { x in
                atlas.cropping(to: CGRect(x: CGFloat(x), y: CGFloat(y), width: sheet.cellSize.width, height: sheet.cellSize.height))
            } }
        } else { frames = [] }
    }
}
