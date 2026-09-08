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
        var doubleJumps: [Double] = []
        var singleJumpPeaks: [CGFloat] = []
        var doubleJumpPeaks: [CGFloat] = []
        private var jumpDirection: CGFloat?
        private var currentJumpPeak: CGFloat = 0
        private var currentJumpIsDouble = false
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
                jumpDirection = before.roamDirection < 0 ? -1 : 1
                currentJumpPeak = 0
                currentJumpIsDouble = false
                expect(before.mode == .roaming && before.onGround && !before.isThrown && before.landingTime <= dt,
                       "An autonomous jump must start from settled free roam")
                expect(!before.isHovered && !before.isDragging && before.portalTime == 0,
                       "An autonomous jump must not interrupt interaction or a portal")
            }
            if before.jumpsUsed == 1 && model.jumpsUsed == 2 {
                doubleJumps.append(model.age)
                currentJumpIsDouble = true
                expect(before.mode == .roaming && !before.onGround && !before.isThrown &&
                       !before.isHovered && !before.isDragging && before.portalTime == 0,
                       "An automatic second jump must belong to an uninterrupted roaming jump")
                expect(model.velocity.dy > before.velocity.dy + 400,
                       "A double jump must add a real upward boost")
            }
            if let direction = jumpDirection {
                currentJumpPeak = max(currentJumpPeak, model.jumpHeight)
                if !model.onGround || model.jumpPreparation > 0 {
                    expect(abs(model.velocity.dx - direction * model.speed) < 0.001,
                           "Every autonomous jump must hold full speed in its original direction")
                    expect(model.facing == (direction > 0 ? .right : .left),
                           "Rick must face the direction of his roaming jump")
                } else {
                    if currentJumpIsDouble { doubleJumpPeaks.append(currentJumpPeak) }
                    else { singleJumpPeaks.append(currentJumpPeak) }
                    jumpDirection = nil
                }
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

    private static func dueDoubleJump() -> (PetModel, SeededRandom) {
        var model = roam(), random = SeededRandom(state: 42)
        for _ in 0..<10800 {
            let previous = model, previousRandom = random
            model.step(1.0 / 60, using: &random)
            if previous.jumpsUsed == 1 && model.jumpsUsed == 2 { return (previous, previousRandom) }
        }
        fatalError("Free roam never scheduled a double jump")
    }

    static func main() {
        // Different refresh rates and random streams must all produce both behaviors,
        // while retaining quiet stretches of walking and resting between them.
        for fps in [30.0, 60.0, 120.0] {
            var singles = 0, doubles = 0
            for seed in [UInt64(1), 42, 2026, 987654] {
                var model = roam(), random = SeededRandom(state: seed)
                let trace = advance(&model, random: &random, seconds: 180, fps: fps)
                expect(trace.jumps.count >= 5 && trace.portals.count >= 2,
                       "Free roam must reliably jump and open portals at \(fps) fps, seed \(seed)")
                expect(trace.peak > 350 && trace.peak < 770 && trace.landings >= 5,
                       "Autonomous jumps must use the high-jump physics and land again")
                expect(trace.singleJumpPeaks.allSatisfy { $0 > 350 && $0 < 385 },
                       "Single roaming jumps must retain their normal height")
                expect(trace.doubleJumpPeaks.allSatisfy { $0 > 650 && $0 < 770 },
                       "Double roaming jumps must gain substantial height without a third boost")
                singles += trace.singleJumpPeaks.count
                doubles += trace.doubleJumpPeaks.count
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
            expect(singles > 0 && doubles > 0, "Free roam must mix single and double jumps at \(fps) fps")
        }

        let (jumpReady, jumpReadyRandom) = due(.jump)
        for fps in [30.0, 60.0, 120.0] {
            for speed: CGFloat in [95, 150, 240] {
                for direction: CGFloat in [-1, 1] {
                    var model = jumpReady, random = jumpReadyRandom
                    model.speed = speed
                    model.roamDirection = direction
                    model.isResting = true
                    model.velocity = .zero
                    let trace = advance(&model, random: &random, seconds: 4, fps: fps)
                    expect(trace.jumps.count == 1 && trace.landings == 1,
                           "A jump from rest must launch at full speed and land at \(speed), \(fps) fps")
                }
            }
        }

        // Interrupt a real, pending second jump, then release the interruption while still airborne.
        let (doubleReady, doubleReadyRandom) = dueDoubleJump()
        var uninterrupted = doubleReady, uninterruptedRandom = doubleReadyRandom
        let doubleTrace = advance(&uninterrupted, random: &uninterruptedRandom, seconds: 3)
        expect(doubleTrace.doubleJumps.count == 1 && uninterrupted.onGround && uninterrupted.jumpsUsed == 0,
               "A planned double jump must boost exactly once and recharge on landing")
        for mode in [PetMode.controlled, .paused] {
            var model = doubleReady, random = doubleReadyRandom
            model.setMode(mode)
            let interrupted = advance(&model, random: &random, seconds: 0.05)
            model.setMode(.roaming)
            let resumed = advance(&model, random: &random, seconds: 3)
            expect(interrupted.doubleJumps.isEmpty && resumed.doubleJumps.isEmpty && model.onGround,
                   "\(mode) must cancel a queued double jump even after returning to free roam")
        }
        var hoveredDouble = doubleReady, hoveredDoubleRandom = doubleReadyRandom
        hoveredDouble.isHovered = true
        let hoveringDouble = advance(&hoveredDouble, random: &hoveredDoubleRandom, seconds: 0.05)
        hoveredDouble.isHovered = false
        let releasedDouble = advance(&hoveredDouble, random: &hoveredDoubleRandom, seconds: 3)
        expect(hoveringDouble.doubleJumps.isEmpty && releasedDouble.doubleJumps.isEmpty && hoveredDouble.onGround,
               "Hover must cancel the second jump without replaying it when the pointer leaves")

        var draggedDouble = doubleReady, draggedDoubleRandom = doubleReadyRandom
        draggedDouble.beginDrag(at: draggedDouble.age)
        draggedDouble.drag(to: CGPoint(x: 700, y: 400), at: draggedDouble.age + 0.1)
        advance(&draggedDouble, random: &draggedDoubleRandom, seconds: 0.1)
        draggedDouble.endDrag(at: draggedDouble.age)
        let thrownDouble = advance(&draggedDouble, random: &draggedDoubleRandom, seconds: 3)
        expect(thrownDouble.doubleJumps.isEmpty,
               "Picking Rick up must discard his pending double jump before he is thrown")

        var portalledDouble = doubleReady, portalledDoubleRandom = doubleReadyRandom
        expect(portalledDouble.portal(to: CGPoint(x: 300, y: 0)), "A manual portal can interrupt a planned double jump")
        let afterDoublePortal = advance(&portalledDouble, random: &portalledDoubleRandom, seconds: 3)
        expect(afterDoublePortal.doubleJumps.isEmpty && portalledDouble.onGround,
               "A portal must discard the pending double jump")

        var manualDouble = doubleReady, manualDoubleRandom = doubleReadyRandom
        expect(manualDouble.jump() && !manualDouble.jump(), "A manual second jump must consume the remaining jump")
        let afterManualDouble = advance(&manualDouble, random: &manualDoubleRandom, seconds: 3)
        expect(afterManualDouble.doubleJumps.isEmpty && manualDouble.onGround && manualDouble.jumpsUsed == 0,
               "A manual second jump must replace the planned automatic boost and land normally")

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

        // An upper display's candidate can fall onto the lower display, where a side Dock
        // clamps it again. Seed 4 at 60 fps previously opened a 106-point trip after 354 s.
        let stackedDisplays = [
            DesktopSurface(frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
                           visibleFrame: CGRect(x: 100, y: 0, width: 900, height: 780)),
            DesktopSurface(frame: CGRect(x: 0, y: 800, width: 1600, height: 900))
        ]
        for fps in [60.0, 30.0, 120.0] {
            for seed in [UInt64(4), 42] {
                var stacked = roam(on: stackedDisplays), stackedRandom = SeededRandom(state: seed)
                let trace = advance(&stacked, random: &stackedRandom, seconds: 600, fps: fps)
                expect(trace.arrivals > 5 && trace.jumps.count > 10,
                       "Stacked displays with a side Dock must retain useful portals and jumps at \(fps) fps, seed \(seed)")
            }
        }

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

        print("Passed \(checks) free-roam checks: directional single/double jumps, portals, cooldowns, hover, focus, naps, drag/throw recovery, manual actions, refresh rates, and monitor geometry.")
    }
}
