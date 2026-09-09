import AppKit

// Controller tests record playback requests without using speakers or real preferences.
private final class RecordingSoundPlayer: SoundPlaying {
    var playingLineID: String?
    var playingEffectID: String?
    var isPlaying: Bool { playingLineID != nil || playingEffectID != nil }
    var requests: [(id: String, volume: Double)] = []
    var volume = 0.0
    var effectDuration = 2.856
    func play(_ line: CharacterLine, volume: Double) -> Double {
        stop();playingLineID=line.id;self.volume=volume
        requests.append((line.id,volume))
        return 3
    }
    func play(_ effect: SoundEffect, volume: Double) -> Double {
        stop();playingEffectID=effect.rawValue;self.volume=volume
        requests.append((effect.rawValue,volume))
        return effectDuration
    }
    func stop() { playingLineID=nil;playingEffectID=nil }
    func setVolume(_ value: Double) { volume=value }
}

@main enum PortalSoundTests {
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64 = 42
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var value = state
            value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
            value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
            return value ^ (value >> 31)
        }
    }

    static func main() {
        _ = NSApplication.shared
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition,message);checks += 1
        }
        let suite = "local.peons.portal-sound-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite);defaults.synchronize() }
        func controller() -> (PetController, RecordingSoundPlayer) {
            defaults.removePersistentDomain(forName:suite)
            let player = RecordingSoundPlayer()
            let owner = PetController(sound:player)
            owner.loadPreferences(from:defaults)
            owner.model.position=CGPoint(x:500,y:0)
            owner.model.setMode(.controlled)
            return (owner,player)
        }
        let destination=CGPoint(x:800,y:0)
        func finishPortal(_ owner: PetController) {
            for _ in 0..<60 {
                owner.model.step(1.0/60)
                owner.handlePortalOpening()
            }
        }

        let (manual,player)=controller()
        manual.say(.shout)
        let firstLine=manual.dialogue.lastID
        let now=ProcessInfo.processInfo.systemUptime
        expect(manual.openPortal(to:destination),"An accepted manual portal must open")
        expect(player.requests.count == 2 && player.playingEffectID == "portal-open" && player.playingLineID == nil,
               "A portal must replace the current voice on the shared player")
        expect(manual.speech == nil && manual.dialogue.lastID == firstLine,
               "Effects must clear stale captions without advancing the voice cycle")
        expect(manual.dialogue.nextLineAt >= now+player.effectDuration && manual.dialogue.nextAutomaticAt >= manual.dialogue.nextLineAt,
               "Chatter must wait for the whole effect, including its tail")
        manual.say(.idle)
        expect(player.requests.count == 2,"Idle chatter must not interrupt the opening cue")
        manual.portal();manual.summon();manual.handlePortalOpening()
        expect(player.requests.count == 2 && manual.model.portalOpenCount == 1,
               "Refused portal and summon requests must not restart the cue")
        finishPortal(manual)
        expect(player.requests.count == 2,"Animation ticks, arrival, and closing must not replay the opening")
        expect(manual.openPortal(to:destination) && player.requests.count == 3,
               "The next trip must play even if no idle frame separated the two trips")
        manual.shout()
        expect(player.playingLineID == CharacterCatalog.ratSuit.lines[1].id && player.playingEffectID == nil,
               "A direct voice request must replace the effect and continue the original cycle")

        let (switching,switchPlayer)=controller()
        switching.say(.greet)
        switching.selectCharacter(CharacterCatalog.peon)
        expect(switchPlayer.playingLineID == CharacterCatalog.peon.lines[0].id && switching.speech == CharacterCatalog.peon.lines[0].text,
               "Character selection must stop Rick and play Peon's matching caption and voice")
        switching.selectCharacter(CharacterCatalog.ratSuit)
        expect(switchPlayer.playingLineID == CharacterCatalog.ratSuit.lines[1].id,
               "Returning to Rick must continue his previous cycle")
        switching.openPortal(to:destination)
        let portalTime=switching.model.portalTime
        switching.selectCharacter(CharacterCatalog.peon)
        expect(switching.model.portalTime == portalTime && switching.model.portalDestination == destination && switchPlayer.playingEffectID == nil,
               "Switching during a portal preserves travel and replaces its sound once")
        expect(switchPlayer.playingLineID == CharacterCatalog.peon.lines[1].id,
               "Returning to Peon must continue his own voice cycle")
        switching.model.setMode(.paused)
        switching.selectCharacter(CharacterCatalog.ratSuit)
        expect(!switchPlayer.isPlaying && switching.speech == nil && switching.model.mode == .paused,
               "Switching a sleeping pet must silence playback and retain its nap")
        switching.model.setMode(.roaming);switching.isHidden=true
        switching.selectCharacter(CharacterCatalog.peon)
        expect(!switchPlayer.isPlaying && switching.isHidden,"Switching a hidden pet must stay hidden and silent")

        let (keyboard,keyPlayer)=controller()
        let view=PetView(frame:CGRect(origin:.zero,size:keyboard.model.size));view.owner=keyboard
        func portalKey(repeated: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,
                            context:nil,characters:"p",charactersIgnoringModifiers:"p",isARepeat:repeated,keyCode:35)!
        }
        view.keyDown(with:portalKey())
        view.keyDown(with:portalKey(repeated:true))
        expect(keyPlayer.requests.count == 1,"P must cue once; keyboard autorepeat must not retrigger it")
        finishPortal(keyboard);keyboard.summon();finishPortal(keyboard);keyboard.portal()
        expect(keyPlayer.requests.count == 3 && keyboard.dialogue.lastID == nil,
               "Summon and the menu portal action must use the effect without consuming dialogue")

        let (held,heldPlayer)=controller()
        held.model.beginDrag(at:0)
        held.portal();held.summon();held.handlePortalOpening()
        expect(heldPlayer.requests.isEmpty && held.model.portalOpenCount == 0,"Dragging must refuse portals silently")

        for suppressed in ["muted","hidden","paused"] {
            let (owner,sound)=controller()
            if suppressed == "muted" { owner.soundEnabled=false }
            if suppressed == "hidden" { owner.isHidden=true }
            if suppressed == "paused" { owner.model.setMode(.paused) }
            owner.openPortal(to:destination)
            expect(sound.requests.isEmpty,"A \(suppressed) portal must remain silent")
            owner.soundEnabled=true;owner.isHidden=false;owner.model.setMode(.controlled)
            owner.handlePortalOpening()
            expect(sound.requests.isEmpty,"Restoring \(suppressed) state must not replay an old opening")
            finishPortal(owner);owner.openPortal(to:destination)
            expect(sound.requests.count == 1,"A later audible portal must still play after \(suppressed) state")
        }

        let (settings,settingsPlayer)=controller()
        settings.setVolume(0.27);settings.openPortal(to:destination)
        expect(settingsPlayer.requests.last?.volume == 0.27 && defaults.double(forKey:"voiceVolume") == 0.27,
               "Effects must inherit the existing persisted volume")
        settings.setVolume(2)
        expect(settingsPlayer.volume == 1 && settings.volume == 1,"Volume updates must affect active effects and clamp high values")
        settings.setVolume(-1)
        expect(settingsPlayer.volume == 0 && settings.volume == 0,"Zero volume must remain silent and clamp low values")
        settings.toggleSound()
        expect(!settingsPlayer.isPlaying && !defaults.bool(forKey:"soundEnabled"),"Mute must immediately stop an active effect and persist")
        settings.toggleSound();settings.handlePortalOpening()
        expect(settingsPlayer.requests.count == 1,"Unmute must not restart an interrupted effect")
        finishPortal(settings);settings.openPortal(to:destination)
        expect(settingsPlayer.requests.last?.volume == 0,"An enabled player must honor saved zero volume")

        let (roaming,roamingPlayer)=controller()
        roaming.model.setMode(.roaming);roaming.chatterEnabled=false
        var random=SeededRandom()
        for _ in 0..<10800 {
            roaming.model.step(1.0/60,using:&random)
            roaming.handlePortalOpening()
            expect(roamingPlayer.requests.count == roaming.model.portalOpenCount,
                   "Every autonomous opening must produce exactly one effect")
        }
        expect(roaming.model.portalOpenCount >= 2 && roaming.dialogue.lastID == nil,
               "Automatic portals must play with chatter disabled and leave the dialogue cycle intact")

        for action in ["silence","sleep","hide","nap","terminate"] {
            let (owner,sound)=controller()
            owner.panel=PetPanel(contentRect:.zero,styleMask:.borderless,backing:.buffered,defer:false)
            owner.openPortal(to:destination)
            switch action {
            case "sleep": owner.willSleep()
            case "hide": owner.toggleHidden()
            case "nap": owner.togglePause()
            case "terminate": owner.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
            default: owner.silence()
            }
            expect(!sound.isPlaying,"\(action) must stop effects just as it stops voices")
        }

        print("Passed \(checks) portal sound checks: manual, keyboard, summon, roaming, exactly-once cues, refusal, dialogue continuity, shared settings, and lifecycle silence.")
    }
}
