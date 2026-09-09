import Foundation
import AVFAudio

@main enum DialogueTests {
    static func main() throws {
        let actions:[CharacterAction]=[.greet,.control,.move,.jump,.toss,.portal,.summon,.select,.shout,.idle]
        for character in CharacterCatalog.all {
            let lines=character.lines
            precondition(!lines.isEmpty,"\(character.name) must have dialogue")
            precondition(Set(lines.map(\.id)).count==lines.count,"Line IDs must be unique within \(character.name)'s pack")
            precondition(lines.allSatisfy{!$0.id.isEmpty && !$0.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty},"Every line needs an ID and caption")
            precondition(character.recordedLineCount==lines.count,"Every shipped line needs a recording")
            var director=DialogueDirector()
            for index in 0..<max(lines.count*2,actions.count*2) {
                let now=Double(index)*10
                let line=director.next(character:character,action:actions[index%actions.count],now:now)!
                precondition(line==lines[index%lines.count],"Every interaction must follow the same complete cycle")
                precondition(director.nextAutomaticAt>=now+18 && director.nextAutomaticAt<=now+35)
                precondition(director.next(character:character,action:.idle,now:now+0.1)==nil,"Automatic chatter must wait for the current line")
            }
        }

        // Rapid direct interactions and silencing preserve Rick's full dialogue cycle.
        let manualActions=actions.filter{$0 != .idle}
        let rick=CharacterCatalog.ratSuit
        var rapid=DialogueDirector()
        for index in 0..<(rick.lines.count*2+3) {
            let now=Double(index)*0.1
            rapid.reset(now:now)
            let line=rapid.next(character:rick,action:manualActions[index%manualActions.count],now:now)!
            precondition(line==rick.lines[index%rick.lines.count],"Rapid interactions and resets must continue Rick's full cycle")
        }

        let character=CharacterCatalog.ratSuit
        let manifestURL=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
            .appendingPathComponent("assets/sounds/rick/openpeon.json")
        let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:manifestURL)) as! [String:Any]
        let categories=manifest["categories"] as! [String:[String:Any]]
        let officialIDs=Set(categories.values.flatMap { category in
            (category["sounds"] as! [[String:Any]]).map { URL(fileURLWithPath:$0["file"] as! String).lastPathComponent }
        })
        let supplementalIDs:Set<String>=["pickle_rick","i_turned_myself_into_a_pickle","hey_morty"]
        precondition(!officialIDs.isEmpty && Set(character.lines.map(\.id)) == officialIDs.union(supplementalIDs),
                     "Rick's complete official manifest and the three selected Pickle Rick clips must be present")
        let peon=CharacterCatalog.peon
        let peonManifestURL=manifestURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("peon/openpeon.json")
        let peonManifest=try JSONSerialization.jsonObject(with:Data(contentsOf:peonManifestURL)) as! [String:Any]
        let peonCategories=peonManifest["categories"] as! [String:[String:Any]]
        let peonIDs=Set(peonCategories.values.flatMap { category in
            (category["sounds"] as! [[String:Any]]).map { URL(fileURLWithPath:$0["file"] as! String).lastPathComponent }
        })
        precondition(peonIDs.count == 17 && Set(peon.lines.map(\.id)) == peonIDs,"The complete official Peon Ping pack must be available")
        var switching=DialogueDirector()
        for index in 0..<40 {
            precondition(switching.next(character:character,action:.select,now:Double(index)) == character.lines[index%character.lines.count])
            switching.reset(now:Double(index))
            precondition(switching.next(character:peon,action:.select,now:Double(index)) == peon.lines[index%peon.lines.count],
                         "Character switching must preserve separate complete voice cycles")
        }
        var timing=DialogueDirector()
        precondition(timing.next(character:character,action:.greet,now:0)==character.lines[0])
        timing.occupy(until:90,now:0)
        timing.occupy(until:50,now:1)
        precondition(timing.nextLineAt==90 && timing.nextAutomaticAt>=90,"The actual clip duration must extend, never shorten, the chatter cooldown")
        precondition(timing.next(character:character,action:.idle,now:89)==nil && timing.lastID==character.lines[0].id)
        timing.rescheduleAutomatic(now:10)
        precondition(timing.nextLineAt==90 && timing.nextAutomaticAt>=90,"Chatter toggle cannot release the playback cooldown")
        precondition(timing.next(character:character,action:.idle,now:90)==character.lines[1],"A blocked idle request must not consume the next line")
        timing.occupy(until:180,now:90)
        timing.reset(now:95)
        precondition(timing.nextLineAt==95 && timing.nextAutomaticAt>=113 && timing.nextAutomaticAt<=130,"Silencing must release playback and reschedule automatic chatter")
        precondition(timing.next(character:character,action:.idle,now:95)==character.lines[2],"Reset must preserve the pack's cursor")
        timing.occupy(until:195,now:95)
        precondition(timing.next(character:character,action:.shout,now:96)==character.lines[3] && timing.nextLineAt==98.5,"Direct input must replace the active clip immediately")

        precondition(SoundPlayer.assetURL("not-a-real-recording.mp3")==nil)
        precondition(SoundEffect.allCases.allSatisfy{$0.audioAsset != nil},"Every effect must have a manifest entry")
        let assets=Set(CharacterCatalog.all.flatMap{$0.lines.compactMap(\.audioAsset)} + SoundEffect.allCases.compactMap(\.audioAsset)).sorted()
        for asset in assets {
            guard let url=SoundPlayer.assetURL(asset) else { fatalError("Missing bundled recording: \(asset)") }
            let file=try AVAudioFile(forReading:url,commonFormat:.pcmFormatFloat32,interleaved:false)
            let format=file.processingFormat
            precondition(file.length>0 && format.sampleRate>0 && format.channelCount>0,"Invalid audio format: \(asset)")
            let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:8192)!
            var frames:AVAudioFramePosition=0
            var peak:Float=0
            while file.framePosition<file.length {
                let remaining=AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity),file.length-file.framePosition))
                try file.read(into:buffer,frameCount:remaining)
                guard buffer.frameLength>0 else { break }
                frames+=AVAudioFramePosition(buffer.frameLength)
                for channel in 0..<Int(format.channelCount) {
                    let samples=UnsafeBufferPointer(start:buffer.floatChannelData![channel],count:Int(buffer.frameLength))
                    for sample in samples {
                        precondition(sample.isFinite,"Invalid decoded sample: \(asset)")
                        peak=max(peak,abs(sample))
                    }
                }
            }
            precondition(frames>0 && peak>0.0001,"Recording must decode into audible samples: \(asset)")
        }
        // Headless CI can decode assets without an output device. Opt in locally to real playback.
        if CommandLine.arguments.contains("--audio-playback") {
            let sound=SoundPlayer()
            precondition(sound.play(character.lines[0],volume:0)>0 && sound.playingLineID == character.lines[0].id,
                         "Playback smoke tests require an available macOS audio output")
            precondition(sound.play(.portalOpen,volume:0)>0 && sound.playingEffectID == "portal-open" && sound.playingLineID == nil,
                         "An effect must replace the voice and clear its diagnostic ID")
            precondition(sound.play(character.lines[1],volume:0)>0 && sound.playingLineID == character.lines[1].id && sound.playingEffectID == nil,
                         "A voice must replace the effect and clear its diagnostic ID")
            precondition(sound.play(peon.lines[0],volume:0)>0 && sound.playingLineID == peon.lines[0].id && sound.playingEffectID == nil,
                         "Peon's WAV must replace Rick on the same player")
            precondition(sound.play(CharacterLine("missing","Missing",audio:"missing.wav"),volume:0)==0 && !sound.isPlaying && sound.playingLineID == nil && sound.playingEffectID == nil,
                         "Missing audio must fail silently and leave no stale playback state")
            sound.play(.portalOpen,volume:0);sound.stop()
            precondition(!sound.isPlaying && sound.playingLineID == nil && sound.playingEffectID == nil)
            let duration=sound.play(.portalOpen,volume:0)
            precondition(duration>0)
            RunLoop.current.run(until:Date(timeIntervalSinceNow:duration+0.3))
            precondition(!sound.isPlaying && sound.playingLineID == nil && sound.playingEffectID == nil,
                         "A naturally finished effect must not remain active in diagnostics")
            print("Passed real audio playback at zero volume: voice/effect replacement, missing asset, stop, and natural completion.")
        }
        print("Passed both complete dialogue packs, independent character cycles, rapid input, cooldown/reset semantics, and \(assets.count) audio decodes.")
    }
}
