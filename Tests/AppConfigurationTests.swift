import AppKit

@main
enum AppConfigurationTests {
    static func main() {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func expectTinyRick(_ controller: PetController) {
            expect(controller.selectedCharacter.id == "rat-suit-rick", "Controls must describe Rat Suit Rick")
            expect(controller.model.character.id == "rat-suit-rick", "The desktop pet must be Rat Suit Rick")
            expect(abs(controller.model.size.width - 135.68) < 0.000001 && abs(controller.model.size.height - 180.2) < 0.000001,
                   "The desktop pet must always use Tiny, including after reloading legacy preferences")
        }
        let suiteName = "local.peons.configuration-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.synchronize()
        }

        let fresh = PetController()
        expectTinyRick(fresh)
        fresh.loadPreferences(from: defaults)
        expectTinyRick(fresh)
        expect(fresh.soundEnabled && fresh.chatterEnabled && fresh.volume == 0.5 && fresh.model.speed == 150,
               "A fresh install must retain the voice and movement defaults")
        expect(defaults.object(forKey: "size") == nil, "A fresh install must not persist an obsolete size selection")

        // Exercise persisted selections from every formerly available character and all old sizes.
        let retiredIDs = [
            "pickle-rick", "peon", "peasant", "wc2_peasant", "murloc", "glados",
            "sc_marine", "sc_firebat", "sc_medic", "sc_kerrigan", "sc_scv", "sc_tank",
            "sc_battlecruiser", "sc_vessel", "sc_terran", "ra2_kirov", "ra2_soviet_engineer",
            "ra_soviet", "tf2_engineer", "hd2_helldiver", "dota2_axe", "duke_nukem",
            "molag_bal", "sheogorath", "ocarina_of_time", "aoe2", "aom_greek",
            "pulp_fiction", "sopranos", "unknown-character"
        ]
        let oldSizes:[Any] = [0, 1, 2, 3, -1, 10000, "invalid"]
        for characterID in ["rat-suit-rick"] + retiredIDs {
            for oldSize in oldSizes {
                defaults.removePersistentDomain(forName: suiteName)
                defaults.set(characterID, forKey: "character")
                defaults.set(oldSize, forKey: "size")
                defaults.set(false, forKey: "soundEnabled")
                defaults.set(false, forKey: "chatterEnabled")
                defaults.set(0.27, forKey: "voiceVolume")
                defaults.set(240.0, forKey: "speed")

                let controller = PetController()
                controller.model.size = CGSize(width: 512, height: 680)
                controller.loadPreferences(from: defaults)
                expectTinyRick(controller)
                expect(!controller.soundEnabled && !controller.chatterEnabled && controller.volume == 0.27,
                       "Migrating appearance must preserve voice, chatter, and volume preferences")
                expect(controller.model.speed == 240, "Migrating appearance must preserve movement speed")
                expect(defaults.string(forKey: "character") == "rat-suit-rick" && defaults.object(forKey: "size") == nil,
                       "Migration must replace retired character IDs and remove the size preference")

                let relaunched = PetController()
                relaunched.loadPreferences(from: defaults)
                expectTinyRick(relaunched)
                expect(!relaunched.soundEnabled && !relaunched.chatterEnabled && relaunched.volume == 0.27 && relaunched.model.speed == 240,
                       "A subsequent launch must preserve voice and speed settings after migration")
            }
        }

        defaults.set(true, forKey: "soundEnabled")
        defaults.set(true, forKey: "chatterEnabled")
        defaults.set(0.0, forKey: "voiceVolume")
        let menuController = PetController()
        menuController.loadPreferences(from: defaults)
        expect(menuController.soundEnabled && menuController.chatterEnabled && menuController.volume == 0,
               "Enabled voices and zero volume must also survive preference loading")
        let menu = menuController.makeMenu()
        func allItems(_ menu: NSMenu) -> [NSMenuItem] {
            menu.items.flatMap { item in [item] + (item.submenu.map(allItems) ?? []) }
        }
        for item in allItems(menu) {
            expect(!["size", "character", "characters"].contains(item.title.lowercased()),
                   "The context and menu-bar menus must not offer appearance selectors")
            if let action = item.action {
                expect(!["chooseSize:", "chooseCharacter:"].contains(NSStringFromSelector(action)),
                       "No menu may invoke a removed appearance selector")
            }
        }
        let titles = Set(menu.items.map(\.title))
        expect(titles.contains("Rick controls…") && titles.contains("Sound · M to mute") && titles.contains("Occasional chatter") && titles.contains("Speed"),
               "Rick controls, voice settings, and speed must remain accessible")

        func inputController() -> (PetController, PetView) {
            let controller = PetController()
            controller.soundEnabled = false
            controller.model.position = CGPoint(x: 500, y: 0)
            controller.model.setMode(.controlled)
            let view = PetView(frame: CGRect(origin: .zero, size: controller.model.size))
            view.owner = controller
            return (controller, view)
        }
        func keyEvent(_ type: NSEvent.EventType = .keyDown, key: UInt16 = 2,
                      flags: NSEvent.ModifierFlags = [], repeat isRepeat: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                            characters: "d", charactersIgnoringModifiers: "d", isARepeat: isRepeat, keyCode: key)!
        }
        func advance(_ controller: PetController) {
            for _ in 0..<60 { controller.model.step(1.0 / 60) }
        }
        let (walking, walkingView) = inputController()
        walkingView.keyDown(with: keyEvent())
        advance(walking)
        let (preheldShift, preheldView) = inputController()
        // Taking control clears the key set, including a Shift press seen before the focus transition.
        preheldView.flagsChanged(with: keyEvent(.flagsChanged, key: 56, flags: .shift))
        preheldShift.model.setMode(.controlled)
        expect(preheldShift.model.keys.isEmpty, "Taking control must clear previous movement state")
        preheldView.keyDown(with: keyEvent(flags: .shift))
        advance(preheldShift)
        expect(abs(preheldShift.model.distance / walking.model.distance - 2) < 0.01,
               "A movement event with Shift already held before focus must sprint immediately")

        // Ordinary key events also repair a missed modifier release, including while a key repeats.
        preheldView.keyDown(with: keyEvent(repeat: true))
        advance(preheldShift)
        expect(abs(preheldShift.model.velocity.dx - walking.model.speed) < 0.01,
               "An unmodified repeated movement event must clear stale Shift and return to walking speed")
        preheldView.flagsChanged(with: keyEvent(.flagsChanged, key: 60, flags: .shift))
        preheldView.keyUp(with: keyEvent(.keyUp, key: 4))
        expect(!preheldShift.model.keys.contains(56) && !preheldShift.model.keys.contains(60),
               "A key-up event without Shift must clear stale modifier state")

        for firstShift in [UInt16(56), 60] {
            let (sprinting, sprintView) = inputController()
            let otherShift: UInt16 = firstShift == 56 ? 60 : 56
            sprintView.keyDown(with: keyEvent())
            sprintView.flagsChanged(with: keyEvent(.flagsChanged, key: firstShift, flags: .shift))
            sprintView.flagsChanged(with: keyEvent(.flagsChanged, key: otherShift, flags: .shift))
            sprintView.flagsChanged(with: keyEvent(.flagsChanged, key: firstShift, flags: .shift))
            advance(sprinting)
            expect(abs(sprinting.model.distance / walking.model.distance - 2) < 0.01,
                   "Releasing one Shift key while the other remains held must keep sprinting")
            sprintView.flagsChanged(with: keyEvent(.flagsChanged, key: otherShift))
            advance(sprinting)
            expect(abs(sprinting.model.velocity.dx - walking.model.speed) < 0.01,
                   "Releasing the final Shift key must return to walking speed")
        }

        let (shortcut, shortcutView) = inputController()
        shortcutView.keyDown(with: keyEvent(flags: [.command, .shift]))
        shortcutView.keyDown(with: keyEvent(key: 49, flags: .command))
        advance(shortcut)
        expect(shortcut.model.distance == 0 && shortcut.model.jumpsUsed == 0,
               "Command shortcuts must not trigger movement or jumping when synchronizing modifiers")
        shortcutView.keyDown(with: keyEvent())
        shortcutView.keyUp(with: keyEvent(.keyUp, flags: .command))
        expect(!shortcut.model.keys.contains(2), "Movement key-up must still release the key while Command is held")
        print("Passed \(checks) app configuration checks: Tiny Rick defaults, retired preference migration, relaunch, preserved voice/speed settings, menus without appearance selectors, and modifier-aware keyboard input.")
    }
}
