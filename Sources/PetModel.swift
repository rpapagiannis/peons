import Foundation
import CoreGraphics

enum PetMode: String { case roaming, controlled, paused }
enum PetFacing: String { case front, back, left, right }

struct PetModel {
    var character = CharacterCatalog.defaultCharacter
    private(set) var surfaces: [DesktopSurface] = []
    private(set) var activeSurface = 0
    // Screen coordinates of the feet, not the transparent window's origin.
    var position = CGPoint.zero
    var velocity = CGVector.zero
    var bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    static let desktopSize = CGSize(width:256 * 0.53,height:340 * 0.53)
    var size = Self.desktopSize
    var mode: PetMode = .roaming
    var speed: CGFloat = 150
    var keys = Set<UInt16>()
    var minimumKeyTime: [UInt16: Double] = [:]
    var facing: PetFacing = .front
    var frontLocked = false
    var turnTime = 0.0
    var idleTime = 0.0
    var isHovered = false
    var jumpPreparation = 0.0
    var landingTime = 0.0
    var phase: CGFloat = 0
    var age = 0.0
    var nextDecision = 0.0
    var roamDirection: CGFloat = 1
    var isResting = false
    private var roamingJumpDelay: Double?
    private var roamingPortalDelay: Double?
    private var roamingActionDelay = 1.0
    private(set) var isDragging = false
    private(set) var isThrown = false
    private(set) var jumpsUsed = 0
    private var dragTarget: CGPoint?
    private var dragSamples: [(point: CGPoint, time: Double)] = []
    var portalTime = 0.0
    var portalDestination: CGPoint?
    var portalMoved = false
    var distance: CGFloat = 0
    private(set) var wrapCount = 0
    private(set) var lastThrowVelocity = CGVector.zero

    static let gravity: CGFloat = 1800
    static let maximumThrowSpeed: CGFloat = 2800
    static let canvasFootY: CGFloat = 318
    var floorY: CGFloat { desktopFloor(at: position.x) }
    func desktopFloor(at x: CGFloat) -> CGFloat {
        let column = surfaces.filter { x >= $0.frame.minX && x < $0.frame.maxX }
        return column.map { $0.visibleFrame.minY }.min()
            ?? (surfaces.indices.contains(activeSurface) ? surfaces[activeSurface].visibleFrame.minY : bounds.minY)
    }
    var footInset: CGFloat { size.height * (340 - Self.canvasFootY) / 340 }
    var panelOrigin: CGPoint { CGPoint(x: position.x - size.width / 2, y: position.y - footInset) }
    var jumpHeight: CGFloat { max(0, position.y - floorY) }
    var jumpVelocity: CGFloat { velocity.dy }
    var onGround: Bool { jumpHeight < 0.01 && velocity.dy <= 0 }
    var isMovingOnGround: Bool { onGround && abs(velocity.dx) > 4 && !isDragging && mode != .paused && portalTime == 0 }
    var isWalking: Bool { isMovingOnGround }
    var jumpRise: CGFloat {
        let height = surfaces.indices.contains(activeSurface) ? surfaces[activeSurface].visibleFrame.height : bounds.height
        return min(380, max(180, height * 0.42))
    }
    var jumpImpulse: CGFloat { sqrt(2 * Self.gravity * jumpRise) }
    var portalProgress: CGFloat { CGFloat(max(0, min(1, 1 - portalTime / 0.85))) }
    // Safe, grounded destinations for summoning and portals. Travel itself is not clamped here.
    var allowed: CGRect {
        let inset = min(size.width / 2, bounds.width / 2)
        return CGRect(x: bounds.minX + inset, y: floorY, width: max(0, bounds.width - inset * 2), height: 0)
    }
    func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, allowed.minX), allowed.maxX), y: max(point.y, floorY))
    }
    func groundPoint(x: CGFloat) -> CGPoint { CGPoint(x: min(max(x, allowed.minX), allowed.maxX), y: floorY) }

    mutating func selectCharacter(_ value: CharacterDefinition) {
        character = value
        phase = 0
        // Keep a deliberate Down lock when applying the supported character.
        face(frontLocked || abs(velocity.dx)<4 ? .front : velocity.dx>0 ? .right : .left)
    }
    mutating func configureDesktop(_ value: [DesktopSurface]) {
        let grounded = onGround
        surfaces = value.filter { $0.frame.width > 0 && $0.frame.height > 0 }
        if let first = surfaces.first {
            bounds = surfaces.dropFirst().reduce(first.frame) { $0.union($1.frame) }
            activeSurface = surfaceIndex(near: position)
            let frame = surfaces[activeSurface].frame
            position.x = min(max(position.x, frame.minX), frame.maxX)
            if grounded || position.y < floorY { position.y = floorY }
        }
    }
    func surfaceIndex(near point: CGPoint) -> Int {
        if surfaces.indices.contains(activeSurface), surfaces[activeSurface].frame.contains(point) { return activeSurface }
        if let index = surfaces.firstIndex(where: { $0.frame.contains(point) }) { return index }
        return surfaces.indices.min { a, b in
            func distance(_ frame: CGRect) -> CGFloat {
                let dx = max(frame.minX-point.x, 0, point.x-frame.maxX)
                let dy = max(frame.minY-point.y, 0, point.y-frame.maxY)
                return dx*dx + dy*dy
            }
            return distance(surfaces[a].frame) < distance(surfaces[b].frame)
        } ?? 0
    }
    func groundDestination(near point: CGPoint) -> CGPoint {
        guard !surfaces.isEmpty else { return groundPoint(x: point.x) }
        let frame = surfaces[surfaceIndex(near: point)].visibleFrame
        let inset = min(size.width/2, frame.width/2)
        let x = min(max(point.x, frame.minX+inset), frame.maxX-inset)
        return CGPoint(x: x, y: desktopFloor(at:x))
    }
    mutating func placeOnGround(near point: CGPoint) {
        position = groundDestination(near: point)
        activeSurface = surfaceIndex(near: position)
    }
    private mutating func followSurface(wasGrounded: Bool) {
        guard !surfaces.isEmpty else { return }
        // Skip genuinely empty horizontal columns in unusual disconnected layouts.
        // Outer edges retain their full-body wrap margin.
        if position.x>bounds.minX && position.x<bounds.maxX && !surfaces.contains(where:{position.x >= $0.frame.minX && position.x < $0.frame.maxX}) {
            let left=surfaces.map{$0.frame.maxX}.filter{$0 <= position.x}.max()
            let right=surfaces.map{$0.frame.minX}.filter{$0 > position.x}.min()
            if let left,let right {
                position.x = velocity.dx>0 ? right : velocity.dx<0 ? left-0.01 : (position.x-left < right-position.x ? left-0.01 : right)
            }
        }
        let previous = activeSurface
        let candidates = surfaces.indices.filter { position.x >= surfaces[$0].frame.minX && position.x < surfaces[$0].frame.maxX }
        if wasGrounded, !candidates.contains(previous), let nearest = candidates.min(by: {
            abs(surfaces[$0].visibleFrame.minY-position.y) < abs(surfaces[$1].visibleFrame.minY-position.y)
        }) {
            // Unequal display heights still provide a continuous route along their bottoms.
            activeSurface = nearest
            position.y = floorY
        } else {
            activeSurface = surfaceIndex(near: position)
        }
    }

    mutating func setMode(_ value: PetMode) {
        mode = value
        keys.removeAll()
        minimumKeyTime.removeAll()
        // Changing focus must never erase the momentum of a released throw.
        if onGround && !isThrown { velocity.dx = 0 }
        if value == .paused { velocity.dx = 0; jumpPreparation = 0 }
        isResting = false
        nextDecision = age + 1
        resetRoamingActions()
    }
    private mutating func resetRoamingActions() {
        roamingJumpDelay = nil
        roamingPortalDelay = nil
        roamingActionDelay = 1
    }
    mutating func pressKey(_ key: UInt16) {
        if !keys.contains(key) { minimumKeyTime[key] = age + 0.055 }
        keys.insert(key)
        if key == 1 || key == 125 {
            frontLocked = true
            face(.front)
        } else if [UInt16(0), 2, 123, 124].contains(key) && !keys.contains(1) && !keys.contains(125) {
            // A newer direction supersedes a completed Down tap, but never a held Down key.
            minimumKeyTime.removeValue(forKey: 1)
            minimumKeyTime.removeValue(forKey: 125)
            frontLocked = false
        }
    }
    mutating func releaseKey(_ key: UInt16) { keys.remove(key) }
    mutating func face(_ value: PetFacing) {
        if value != facing { facing = value; turnTime = 0.13 }
    }

    @discardableResult mutating func jump() -> Bool {
        guard jumpsUsed < 2 && jumpPreparation == 0 && portalTime == 0 && mode != .paused && !isDragging else { return false }
        jumpsUsed += 1
        landingTime = 0
        isThrown = false
        roamingJumpDelay = nil
        roamingActionDelay = 2
        if onGround { jumpPreparation = 0.10 }
        else { velocity.dy = jumpImpulse }
        return true
    }

    // Returns false when a portal is already open or Rick is being held, so callers can skip their voice line.
    @discardableResult mutating func portal(to point: CGPoint) -> Bool {
        guard portalTime == 0 && !isDragging else { return false }
        portalTime = 0.85
        portalDestination = groundDestination(near: point)
        portalMoved = false
        velocity = .zero
        isThrown = false
        jumpPreparation = 0
        jumpsUsed = 0
        resetRoamingActions()
        return true
    }

    mutating func beginDrag(at time: Double, from start: CGPoint? = nil) {
        isDragging = true
        isThrown = false
        jumpPreparation = 0
        portalTime = 0
        portalDestination = nil
        resetRoamingActions()
        dragTarget = position
        dragSamples = [(start ?? position, time)]
    }
    mutating func drag(to point: CGPoint, at time: Double) {
        guard isDragging else { return }
        dragTarget = point
        dragSamples.append((point, time))
        // A short release window distinguishes a flick from moving, waiting, and dropping.
        // Retain one sample just before the window so a sparse or sub-frame gesture
        // still has a measurable displacement. Stationary releases add a zero-motion sample.
        while dragSamples.count > 2 && dragSamples[1].time < time - 0.12 { dragSamples.removeFirst() }
    }
    mutating func endDrag(at time: Double) {
        guard isDragging else { return }
        if let target = dragTarget { drag(to: target, at: time) }
        if let first = dragSamples.first, let last = dragSamples.last, last.time - first.time > 0.0001 {
            let elapsed = last.time - first.time
            let pointer = CGVector(dx: (last.point.x - first.point.x) / elapsed, dy: (last.point.y - first.point.y) / elapsed)
            velocity.dx = velocity.dx * 0.35 + pointer.dx * 0.65
            velocity.dy = velocity.dy * 0.35 + pointer.dy * 0.65
        }
        limitVelocity()
        lastThrowVelocity = velocity
        isDragging = false
        isThrown = true
        jumpsUsed = 0
        dragTarget = nil
        dragSamples.removeAll()
        nextDecision = age + 1
    }
    private mutating func limitVelocity() {
        let magnitude = hypot(velocity.dx, velocity.dy)
        if magnitude > Self.maximumThrowSpeed {
            velocity.dx *= Self.maximumThrowSpeed / magnitude
            velocity.dy *= Self.maximumThrowSpeed / magnitude
        }
    }
    private mutating func followDrag(_ dt: Double) {
        guard let target = dragTarget else { return }
        // Exact solution of a critically damped spring: stable even after a slow frame.
        let omega: CGFloat = 26
        let decay = exp(-omega * dt)
        let offset = CGVector(dx: position.x - target.x, dy: position.y - target.y)
        let bx = velocity.dx + omega * offset.dx, by = velocity.dy + omega * offset.dy
        position.x = target.x + (offset.dx + bx * dt) * decay
        position.y = target.y + (offset.dy + by * dt) * decay
        velocity = CGVector(dx: (velocity.dx - omega * bx * dt) * decay, dy: (velocity.dy - omega * by * dt) * decay)
        followSurface(wasGrounded: false)
        if position.y < floorY { position.y = floorY; velocity.dy = max(0, velocity.dy) }
        limitVelocity()
    }
    private mutating func wrapSides() {
        // Let the entire body pass out of view, then enter at the opposite edge, as Max does.
        let margin = size.width * 0.42
        if position.x > bounds.maxX + margin {
            position.x = bounds.minX + (position.x - bounds.maxX - margin)
            wrapCount += 1
        } else if position.x < bounds.minX - margin {
            position.x = bounds.maxX - (bounds.minX - margin - position.x)
            wrapCount += 1
        }
    }

    private func roamingPortalDestination<R: RandomNumberGenerator>(using random: inout R) -> CGPoint? {
        // Exclude nearby floor so a portal always takes Rick somewhere visibly different.
        let separation = max(120, size.width * 1.5)
        let frames = surfaces.isEmpty ? [bounds] : surfaces.map(\.visibleFrame)
        var destinations: [(x: ClosedRange<CGFloat>, y: CGFloat)] = []
        for frame in frames {
            let inset = min(size.width / 2, frame.width / 2)
            let left = frame.minX + inset, right = frame.maxX - inset
            let leftEnd = min(right, position.x - separation)
            let rightStart = max(left, position.x + separation)
            if left <= leftEnd { destinations.append((left...leftEnd, frame.midY)) }
            if rightStart <= right { destinations.append((rightStart...right, frame.midY)) }
        }
        guard let destination = destinations.randomElement(using: &random) else { return nil }
        return groundDestination(near: CGPoint(x: CGFloat.random(in: destination.x, using: &random), y: destination.y))
    }

    private mutating func updateRoamingActions<R: RandomNumberGenerator>(_ dt: Double, using random: inout R) {
        guard mode == .roaming else { return }
        if isHovered { roamingActionDelay = max(roamingActionDelay, 1); return }
        guard onGround, !isThrown, jumpPreparation == 0, landingTime == 0 else { return }
        // Count only unoccupied time on the floor, so hovering, throws and focus changes
        // cannot build up a burst of overdue actions. Portals take priority if both are due.
        roamingActionDelay = max(0, roamingActionDelay - dt)
        guard roamingActionDelay == 0 else { return }
        roamingJumpDelay = (roamingJumpDelay ?? Double.random(in: 8...16, using: &random)) - dt
        roamingPortalDelay = (roamingPortalDelay ?? Double.random(in: 25...45, using: &random)) - dt
        if let delay = roamingPortalDelay, delay <= 0 {
            if let destination = roamingPortalDestination(using: &random), portal(to: destination) {
                isResting = false
                frontLocked = false
                nextDecision = age + 2
                return
            }
            // A very narrow desktop may have no useful destination. Keep walking and jumping.
            roamingPortalDelay = Double.random(in: 25...45, using: &random)
        }
        if let delay = roamingJumpDelay, delay <= 0, jump() {
            isResting = false
            frontLocked = false
            nextDecision = age + 2
        }
    }

    mutating func step(_ delta: Double) {
        var random = SystemRandomNumberGenerator()
        step(delta, using: &random)
    }

    mutating func step<R: RandomNumberGenerator>(_ delta: Double, using random: inout R) {
        let dt = min(max(delta, 0), 0.05)
        guard dt > 0 else { return }
        age += dt
        turnTime = max(0, turnTime - dt)
        landingTime = max(0, landingTime - dt)
        minimumKeyTime = minimumKeyTime.filter { $0.value > age }
        if portalTime > 0 {
            portalTime = max(0, portalTime - dt)
            if portalTime <= 0.425 && !portalMoved {
                position = groundDestination(near: portalDestination ?? position)
                activeSurface = surfaceIndex(near: position)
                portalMoved = true
            }
            return
        }
        if isDragging { followDrag(dt); idleTime = 0; return }
        updateRoamingActions(dt, using: &random)
        if portalTime > 0 { return }
        if jumpPreparation > 0 {
            jumpPreparation = max(0, jumpPreparation - dt)
            if jumpPreparation < 0.0001 { jumpPreparation = 0; velocity.dy = jumpImpulse }
        }

        var direction: CGFloat = 0
        var actualSpeed = speed
        let held = keys.union(minimumKeyTime.keys)
        let down = held.contains(1) || held.contains(125)
        if mode == .controlled {
            if held.contains(0) || held.contains(123) { direction -= 1 }
            if held.contains(2) || held.contains(124) { direction += 1 }
            if held.contains(56) || held.contains(60) { actualSpeed *= 2 }
        } else if mode == .roaming && onGround && !isThrown {
            if age >= nextDecision && !isHovered && jumpPreparation == 0 {
                isResting = Double.random(in: 0...1, using: &random) < 0.24
                roamDirection = Bool.random(using: &random) ? 1 : -1
                frontLocked = false
                nextDecision = age + (isResting ? Double.random(in: 1.5...3.5, using: &random) : Double.random(in: 2.8...6, using: &random))
            }
            if !isResting && !isHovered { direction = roamDirection }
            actualSpeed *= 0.32
        }
        if down { frontLocked = true; face(.front) }
        else if !frontLocked && direction != 0 { face(direction > 0 ? .right : .left) }
        else if !frontLocked && !onGround && abs(velocity.dx) > 15 { face(velocity.dx > 0 ? .right : .left) }

        // Small substeps make landings and fast throws independent of display refresh rate.
        let steps = max(1, Int(ceil(dt * 120)))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            let grounded = onGround
            if direction != 0 && mode != .paused {
                let response = 1 - exp(-h / (grounded ? 0.075 : 0.20))
                velocity.dx += (direction * actualSpeed - velocity.dx) * response
                if grounded { isThrown = false }
            } else if grounded {
                velocity.dx *= exp(-h / (isThrown ? 0.23 : 0.055))
            } else {
                velocity.dx *= exp(-0.6 * h)
            }
            if abs(velocity.dx) < 0.8 { velocity.dx = 0 }
            if !grounded || velocity.dy > 0 { velocity.dy -= Self.gravity * h }
            let dx = velocity.dx * h
            position.x += dx
            position.y += velocity.dy * h
            distance += abs(dx)
            wrapSides()
            followSurface(wasGrounded: grounded)
            if position.y <= floorY {
                let impact = -velocity.dy
                position.y = floorY
                if impact > 80 { landingTime = 0.22 }
                // Tosses bounce and lose energy. Ordinary jumps settle into their landing pose.
                if isThrown && impact > 180 && mode != .paused { velocity.dy = impact * 0.48 }
                else {
                    velocity.dy = 0
                    if jumpPreparation == 0 { jumpsUsed = 0 }
                    if abs(velocity.dx) < 4 { isThrown = false }
                }
            }
            if grounded && abs(dx) > 0 { phase += abs(dx) / (64 * size.width / 256) * (.pi * 2) }

        }
        if isMovingOnGround { idleTime = 0 }
        else {
            idleTime += dt
            if idleTime > 0.16 { phase = 0 }
        }
    }
}
