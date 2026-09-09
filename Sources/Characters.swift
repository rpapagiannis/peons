import Foundation
import CoreGraphics

enum CharacterAction: String { case greet, select, control, move, jump, toss, portal, summon, idle, shout }

struct CharacterLine: Identifiable, Equatable, Decodable {
    let id: String
    let text: String
    let audioAsset: String?
    init(_ id:String,_ text:String,audio:String? = nil) { self.id=id;self.text=text;audioAsset=audio }
}

struct CharacterVoicePack {
    let id: String
    let lines: [CharacterLine]
}

struct SpriteSheetDefinition {
    let assetName: String
    // Front, side, and back sequences may use different layouts and pose counts.
    let frameRects: [[CGRect]]
    let footCorrections: [[CGFloat]]
    var drawSize = CGSize(width:200,height:256)
    var walkFrames = [0,1,2,3]
    var pixelArt = false
    var mirrorsRight = true
}

struct CharacterDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let shortName: String
    let collection: String
    let headline: String
    let sprites: SpriteSheetDefinition
    let voicePack: CharacterVoicePack
    var lines: [CharacterLine] { voicePack.lines }
    var recordedLineCount: Int { lines.filter{$0.audioAsset != nil}.count }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

enum CharacterCatalog {
    // Dialogue belongs to a character, never to the shared desktop controller.
    private static let rickVoice = CharacterVoicePack(id:"peon-ping-rick",lines:loadLines("rick"))
    private static let peonVoice = CharacterVoicePack(id:"peon-ping-peon",lines:loadLines("peon"))
    static func loadLines(_ directory:String) -> [CharacterLine] {
        let paths=[Bundle.main.resourceURL?.appendingPathComponent("sounds/\(directory)/lines.json"),
                   URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("assets/sounds/\(directory)/lines.json")]
        for path in paths.compactMap({$0}) {
            if let data=try? Data(contentsOf:path),let lines=try? JSONDecoder().decode([CharacterLine].self,from:data) { return lines }
        }
        return []
    }
    static let ratSuit = CharacterDefinition(
        id: "rat-suit-rick", name: "Rat Suit Rick", shortName: "Rick", collection: "Rick and Morty", headline: "Tiny Rick.\nBig attitude.",
        sprites: SpriteSheetDefinition(assetName: "rat-suit-pickle-rick-atlas.png",
            frameRects: [740,907,1075].map { y in [5,135,265,395].map { x in CGRect(x:x,y:y,width:125,height:160) } },
            footCorrections:[[0,0,0,1],[2,4,2,2],[-1,2,-1,-1]]),
        voicePack:rickVoice)
    static let peon = CharacterDefinition(
        id: "peon", name: "Warcraft Peon", shortName: "Peon", collection: "Warcraft", headline: "Ready to work.\nBorn to roam.",
        sprites: SpriteSheetDefinition(assetName: "warcraft-peon-sheet.png",
            // The original sheet orders north, northeast, east, southeast, south.
            frameRects: [203,108,5].map { x in [0,38,79,120,161].map { y in CGRect(x:x,y:y,width:46,height:38) } },
            // Align the opaque foot baseline of each original crop at 5x native pixels.
            footCorrections:[[34,4,9,4,9],[19,24,19,24,9],[19,9,9,14,9]],
            drawSize:CGSize(width:230,height:190),walkFrames:[1,2,3,4],pixelArt:true,mirrorsRight:false),
        voicePack:peonVoice)
    static let all = [ratSuit,peon]
    // Unknown and retired selections still migrate to Rick; supported IDs persist.
    static let defaultCharacter = ratSuit
    static func resolve(_ id: String?) -> CharacterDefinition {
        all.first { $0.id == id } ?? defaultCharacter
    }
}

struct DesktopSurface {
    let frame: CGRect
    let visibleFrame: CGRect
    init(frame: CGRect, visibleFrame: CGRect? = nil) {
        self.frame = frame
        self.visibleFrame = visibleFrame ?? frame
    }
}
