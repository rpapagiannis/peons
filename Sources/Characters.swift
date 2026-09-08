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
    let columns: [Int]
    let rows: [Int]
    let cellSize: CGSize
    let footCorrections: [[CGFloat]]
}

struct CharacterDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let collection: String
    let sprites: SpriteSheetDefinition
    let voicePack: CharacterVoicePack
    var lines: [CharacterLine] { voicePack.lines }
    var recordedLineCount: Int { lines.filter{$0.audioAsset != nil}.count }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

enum CharacterCatalog {
    // Dialogue belongs to a character, never to the shared desktop controller.
    private static let rickVoice = CharacterVoicePack(id:"peon-ping-rick",lines:loadLines("rick"))
    static func loadLines(_ directory:String) -> [CharacterLine] {
        let paths=[Bundle.main.resourceURL?.appendingPathComponent("sounds/\(directory)/lines.json"),
                   URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("assets/sounds/\(directory)/lines.json")]
        for path in paths.compactMap({$0}) {
            if let data=try? Data(contentsOf:path),let lines=try? JSONDecoder().decode([CharacterLine].self,from:data) { return lines }
        }
        return []
    }
    static let ratSuit = CharacterDefinition(
        id: "rat-suit-rick", name: "Rat Suit Rick", collection: "Rick and Morty",
        sprites: SpriteSheetDefinition(assetName: "rat-suit-pickle-rick-atlas.png", columns: [5,135,265,395], rows: [740,907,1075], cellSize: CGSize(width:125,height:160), footCorrections:[[0,0,0,1],[2,4,2,2],[-1,2,-1,-1]]),
        voicePack:rickVoice)
    static let all = [ratSuit]
    // Retired selections always migrate to the single supported character.
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
