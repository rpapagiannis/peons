import Foundation
import CoreGraphics

// A reproducible random stream exercises the same scheduler used by the live app.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

@main
enum RoamingTests {
    static var checks = 0
    static func expect(_ condition: Bool, _ message: String) {
        precondition(condition, message)
        checks += 1
    }

    struct Trace {
        var jumps: [Double] = []
        var portals: [Double] = []
        var destinations: [CGPoint] = []
        var peak: CGFloat = 0
        var walkingFrames = 0
        var restingFrames = 0
        var landings = 0
        var arrivals = 0

        mutating func step(_ model: inout PetModel, random: inout SeededRandom, dt: Double) {
            let before = model
            model.step(dt, using: &random)
            if before.jumpPreparation == 0 && model.jumpPreparation > 0 {
                jumps.append(model.age)
                expect(before.mode == .roaming && before.onGround && !before.isThrown && before.landingTime <= dt,
                       "An autonomous jump must start from settled free roam")
                expect(!before.isHovered && !before.isDragging && before.portalTime == 0,
                       "An autonomous jump must not interrupt interaction or a portal")
            }
            if before.portalTime == 0 && model.portalTime > 0 {
                portals.append(model.age)
                let destination = model.portalDestination!
                destinations.append(destination)
                expect(before.mode == .roaming && before.onGround && !before.isThrown && before.landingTime <= dt,
                       "An autonomous portal must wait for landing and throw recovery")
                expect(!before.isHovered && !before.isDragging && before.jumpPreparation == 0,
                       "An autonomous portal must not interrupt interaction or a jump")
                expect(abs(destination.x - before.position.x) >= max(120, model.size.width * 1.5) - 0.001,
                       "An autonomous portal must travel a visible distance")
                expect(destination == model.groundDestination(near: destination),
                       "The portal destination must be a safe, visible floor position")
                expect(model.position == before.position && model.velocity == .zero,
                       "Opening a portal must stop motion and wait for the animation midpoint")
            }
            if before.portalTime > 0 && !before.portalMoved && model.portalMoved {
                arrivals += 1
                expect(model.position == model.groundDestination(near: before.portalDestination!) && model.onGround,
                       "The midpoint must place Rick on the current desktop's floor")
            }
            if !before.onGround && model.onGround && model.portalTime == 0 { landings += 1 }
            peak = max(peak, model.jumpHeight)
            if model.isWalking { walkingFrames += 1 }
            if model.onGround && model.isResting { restingFrames += 1 }
        }
    }

    static func roam(on surfaces: [DesktopSurface] = []) -> PetModel {
        var model = PetModel()
        model.position = CGPoint(x: 500, y: 0)
        model.configureDesktop(surfaces)
        model.setMode(.roaming)
        return model
    }

    @discardableResult
    private static func advance(_ model: inout PetModel, random: inout SeededRandom,
                                seconds: Double, fps: Double = 60) -> Trace {
        var trace = Trace()
        for _ in 0..<Int(seconds * fps) { trace.step(&model, random: &random, dt: 1 / fps) }
        return trace
    }

    // Stop one frame before a real scheduled action, without reaching into its timers.
    private static func due(_ action: CharacterAction) -> (PetModel, SeededRandom) {
        var model = roam(), random = SeededRandom(state: 42)
        for _ in 0..<7200 {
            let previous = model, previousRandom = random
            model.step(1.0 / 60, using: &random)
            if action == .jump && previous.jumpPreparation == 0 && model.jumpPreparation > 0 ||
                action == .portal && previous.portalTime == 0 && model.portalTime > 0 {
                return (previous, previousRandom)
            }
        }
        fatalError("Free roam never scheduled \(action)")
    }

    static func main() {
        // Different refresh rates and random streams must all produce both behaviors,
        // while retaining quiet stretches of walking and resting between them.
        for fps in [30.0, 60.0, 120.0] {
            for seed in [UInt64(1), 42, 2026, 987654] {
                var model = roam(), random = SeededRandom(state: seed)
                let trace = advance(&model, random: &random, seconds: 180, fps: fps)
                expect(trace.jumps.count >= 5 && trace.portals.count >= 2,
                       "Free roam must reliably jump and open portals at \(fps) fps, seed \(seed)")
                expect(trace.peak > 350 && trace.peak < 385 && trace.landings >= 5,
                       "Autonomous jumps must use the high-jump physics and land again")
                expect(trace.walkingFrames > 0 && trace.restingFrames > 0,
                       "Free roam must still include walking and resting")
                expect(trace.arrivals >= trace.portals.count - 1,
                       "Autonomous portals must complete their animations")
                for (first, second) in zip(trace.jumps, trace.jumps.dropFirst()) {
                    expect(second - first >= 8, "Autonomous jumps must have a cooldown")
                }
                for (first, second) in zip(trace.portals, trace.portals.dropFirst()) {
                    expect(second - first >= 25, "Autonomous portals must remain occasional")
                }
            }
        }

        for action in [CharacterAction.jump, .portal] {
            let (ready, readyRandom) = due(action)
            for mode in [PetMode.controlled, .paused] {
                var model = ready, random = readyRandom
                model.setMode(mode)
                let trace = advance(&model, random: &random, seconds: 90)
                expect(trace.jumps.isEmpty && trace.portals.isEmpty && model.onGround,
                       "\(mode) must suppress a pending autonomous \(action)")
                model.setMode(.roaming)
                let resumed = advance(&model, random: &random, seconds: 6)
                expect(resumed.jumps.isEmpty && resumed.portals.isEmpty,
                       "Returning to free roam must give Rick a fresh cooldown")
            }

            var hovered = ready, hoverRandom = readyRandom
            hovered.isHovered = true
            let hovering = advance(&hovered, random: &hoverRandom, seconds: 90)
            expect(hovering.jumps.isEmpty && hovering.portals.isEmpty && hovered.velocity == .zero,
                   "Hover must suppress a pending \(action) for as long as Rick is being caught")
            hovered.isHovered = false
            let grace = advance(&hovered, random: &hoverRandom, seconds: 0.5)
            expect(grace.jumps.isEmpty && grace.portals.isEmpty, "Leaving hover must allow a short grace period")
            let resumed = advance(&hovered, random: &hoverRandom, seconds: 2)
            expect(action == .jump ? !resumed.jumps.isEmpty : !resumed.portals.isEmpty,
                   "Hover must defer the scheduled action without disabling free roam")

            var falling = ready, fallRandom = readyRandom
            falling.position.y = 600
            let airborne = advance(&falling, random: &fallRandom, seconds: 0.4)
            expect(airborne.jumps.isEmpty && airborne.portals.isEmpty && falling.position.y < 600,
                   "An unsupported Rick must fall without an autonomous midair action")

            var held = ready, heldRandom = readyRandom
            held.beginDrag(at: 0)
            held.drag(to: CGPoint(x: 650, y: 400), at: 0.1)
            let dragging = advance(&held, random: &heldRandom, seconds: 5)
            expect(dragging.jumps.isEmpty && dragging.portals.isEmpty && held.isDragging && held.position.y > 390,
                   "Dragging must keep control of Rick even with an autonomous action due")
            held.drag(to: CGPoint(x: 850, y: 600), at: 5.01)
            held.endDrag(at: 5.02)
            let throwing = advance(&held, random: &heldRandom, seconds: 0.5)
            expect(throwing.jumps.isEmpty && throwing.portals.isEmpty && held.isThrown,
                   "Autonomous actions must preserve a released throw")
        }

        // A user's manual actions still work, and restart the matching cooldown.
        var (manualJump, jumpRandom) = due(.jump)
        expect(manualJump.jump(), "Manual jump must remain available in free roam")
        let afterJump = advance(&manualJump, random: &jumpRandom, seconds: 6)
        expect(afterJump.jumps.isEmpty, "A manual jump must postpone the next automatic jump")
        var (manualPortal, portalRandom) = due(.portal)
        expect(manualPortal.portal(to: CGPoint(x: 400, y: 0)), "Manual portals must remain available in free roam")
        let afterPortal = advance(&manualPortal, random: &portalRandom, seconds: 6)
        expect(afterPortal.portals.isEmpty && afterPortal.jumps.isEmpty,
               "A manual portal must be followed by a quiet cooldown")

        let displays = [
            DesktopSurface(frame: CGRect(x: -1200, y: -200, width: 1200, height: 900),
                           visibleFrame: CGRect(x: -1200, y: -160, width: 1200, height: 830)),
            DesktopSurface(frame: CGRect(x: 0, y: 0, width: 1000, height: 800)),
            DesktopSurface(frame: CGRect(x: 1200, y: 200, width: 900, height: 800))
        ]
        var desktop = roam(on: displays), desktopRandom = SeededRandom(state: 42)
        let across = advance(&desktop, random: &desktopRandom, seconds: 600)
        for frame in displays.map(\.visibleFrame) {
            expect(across.destinations.contains { $0.x >= frame.minX && $0.x <= frame.maxX },
                   "Autonomous portals must be able to visit every connected monitor")
        }
        expect(across.jumps.count > 10 && across.arrivals > 5,
               "Free roam must keep working with monitor gaps, negative origins and unequal floors")

        var (removed, removedRandom) = due(.portal)
        removed.step(1.0 / 60, using: &removedRandom)
        removed.configureDesktop([DesktopSurface(frame: CGRect(x: -900, y: -100, width: 700, height: 700))])
        advance(&removed, random: &removedRandom, seconds: 1)
        expect(removed.onGround && removed.position.x >= -900 && removed.position.x <= -200,
               "A display change during a portal must bring Rick onto a remaining screen")

        let narrowScreen = DesktopSurface(frame: CGRect(x: -100, y: 0, width: 180, height: 800))
        var narrow = roam(on: [narrowScreen]), narrowRandom = SeededRandom(state: 42)
        // Keep the walking position centered: this screen has no sufficiently distant destination.
        narrow.speed = 0
        narrow.placeOnGround(near: CGPoint(x: -10, y: 0))
        let tiny = advance(&narrow, random: &narrowRandom, seconds: 180)
        expect(tiny.portals.isEmpty && tiny.jumps.count > 5 && tiny.landings > 5,
               "A narrow desktop must skip useless portals while keeping jumps and landings working")

        print("Passed \(checks) free-roam checks: autonomous high jumps, portals, cooldowns, hover, focus, naps, drag/throw recovery, manual actions, refresh rates, and monitor geometry.")
    }
}
