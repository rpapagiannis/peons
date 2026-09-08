import AVFAudio
import Foundation

enum SoundEffect: String, CaseIterable {
    case portalOpen = "portal-open"

    private struct Asset: Decodable {
        let id: String
        let audioAsset: String
    }
    private static let assets: [Asset] = {
        guard let url=SoundPlayer.assetURL("effects/effects.json"),
              let data=try? Data(contentsOf:url),
              let assets=try? JSONDecoder().decode([Asset].self,from:data) else { return [] }
        return assets
    }()
    var audioAsset: String? { Self.assets.first{$0.id == rawValue}?.audioAsset }
}

protocol SoundPlaying: AnyObject {
    var isPlaying: Bool { get }
    var playingLineID: String? { get }
    var playingEffectID: String? { get }
    @discardableResult func play(_ line:CharacterLine,volume:Double) -> Double
    @discardableResult func play(_ effect:SoundEffect,volume:Double) -> Double
    func setVolume(_ value:Double)
    func stop()
}

// Voices and effects share one channel, asset lookup, and volume policy. Never layer recordings.
final class SoundPlayer: SoundPlaying {
    private var player: AVAudioPlayer?
    private var currentLineID: String?
    private var currentEffectID: String?
    var isPlaying: Bool { player?.isPlaying ?? false }
    // A clip that has finished is no longer playing; diagnostics must not report it as active.
    var playingLineID: String? { isPlaying ? currentLineID : nil }
    var playingEffectID: String? { isPlaying ? currentEffectID : nil }
    static func assetURL(_ path:String) -> URL? {
        let bundled=Bundle.main.resourceURL?.appendingPathComponent("sounds").appendingPathComponent(path)
        let local=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("assets/sounds").appendingPathComponent(path)
        return [bundled,local].compactMap{$0}.first{FileManager.default.fileExists(atPath:$0.path)}
    }
    @discardableResult func play(_ line:CharacterLine,volume:Double) -> Double {
        play(asset:line.audioAsset,lineID:line.id,effectID:nil,volume:volume)
    }
    @discardableResult func play(_ effect:SoundEffect,volume:Double) -> Double {
        play(asset:effect.audioAsset,lineID:nil,effectID:effect.rawValue,volume:volume)
    }
    private func play(asset:String?,lineID:String?,effectID:String?,volume:Double) -> Double {
        stop()
        guard let asset,let url=Self.assetURL(asset),let audio=try? AVAudioPlayer(contentsOf:url) else { return 0 }
        audio.volume=Float(min(1,max(0,volume)))
        guard audio.prepareToPlay(),audio.play() else { return 0 }
        player=audio;currentLineID=lineID;currentEffectID=effectID
        return audio.duration
    }
    func setVolume(_ value:Double) { player?.volume=Float(min(1,max(0,value))) }
    func stop() { player?.stop();player=nil;currentLineID=nil;currentEffectID=nil }
}
