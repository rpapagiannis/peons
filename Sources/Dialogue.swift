import Foundation

// Every direct interaction advances the same full, ordered voice-pack cycle.
struct DialogueDirector {
    private var cursors: [String:Int] = [:]
    private(set) var lastID: String?
    private(set) var nextLineAt: Double = 0
    private(set) var nextAutomaticAt: Double = 0

    mutating func next(character:CharacterDefinition,action:CharacterAction,now:Double) -> CharacterLine? {
        let pool=character.lines
        guard !pool.isEmpty,action != .idle || now>=nextLineAt else { return nil }
        let key=character.voicePack.id
        let index=(cursors[key] ?? 0)%pool.count
        let line=pool[index];cursors[key]=(index+1)%pool.count;lastID=line.id
        // Direct input deliberately replaces the current line. Never layer voices.
        nextLineAt=now
        occupy(until:now+2.5,now:now)
        return line
    }
    mutating func occupy(until:Double,now:Double) {
        nextLineAt=max(nextLineAt,until)
        nextAutomaticAt=max(nextLineAt,now+Double.random(in:18...35))
    }
    mutating func reset(now:Double) {
        nextLineAt=now
        rescheduleAutomatic(now:now)
    }
    mutating func rescheduleAutomatic(now:Double) { nextAutomaticAt=max(nextLineAt,now+Double.random(in:18...35)) }
}
