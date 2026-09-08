import AVFAudio
import Foundation

final class VoicePlayer {
    private var player: AVAudioPlayer?
    private var currentLineID: String?
    var isPlaying: Bool { player?.isPlaying ?? false }
    // A clip that has finished is no longer playing; diagnostics must not report it as active.
    var playingLineID: String? { isPlaying ? currentLineID : nil }
    static func assetURL(_ path:String) -> URL? {
        let bundled=Bundle.main.resourceURL?.appendingPathComponent("sounds").appendingPathComponent(path)
        let local=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("assets/sounds").appendingPathComponent(path)
        return [bundled,local].compactMap{$0}.first{FileManager.default.fileExists(atPath:$0.path)}
    }
    @discardableResult func play(_ line:CharacterLine,volume:Double) -> Double {
        stop()
        guard let asset=line.audioAsset,let url=Self.assetURL(asset),let audio=try? AVAudioPlayer(contentsOf:url) else { return 0 }
        audio.volume=Float(min(1,max(0,volume)))
        guard audio.prepareToPlay(),audio.play() else { return 0 }
        player=audio;currentLineID=line.id
        return audio.duration
    }
    func setVolume(_ value:Double) { player?.volume=Float(min(1,max(0,value))) }
    func stop() { player?.stop();player=nil;currentLineID=nil }
}
