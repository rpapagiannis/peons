import Foundation
import CoreGraphics

@main
enum ModelTests {
    static func main() {
        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            guard condition else { fatalError(message) }; checks += 1
        }
        func controlled() -> PetModel {
            var model = PetModel(); model.position = CGPoint(x: 500, y: 0); model.setMode(.controlled); return model
        }
        func advance(_ model: inout PetModel, _ seconds: Double, fps: Double = 60) {
            for _ in 0..<Int(seconds * fps) { model.step(1 / fps) }
        }
        var right = controlled(); right.pressKey(2); advance(&right, 1)
        expect(right.position.x > 630 && right.position.x < 650, "D must accelerate to walking speed")
        expect(right.position.y == right.floorY && right.isWalking, "Walking must stay planted on the floor")
        expect(right.facing == .right, "D must face right")
        var left = controlled(); left.pressKey(123); advance(&left, 1)
        expect(left.position.x < 370 && left.facing == .left, "Left arrow must walk left")
        var opposing = controlled(); opposing.keys = [0, 2]; advance(&opposing, 1)
        expect(opposing.position == CGPoint(x: 500, y: 0), "Opposite horizontal inputs must cancel")
        var sprint = controlled(); sprint.keys = [2, 56]; advance(&sprint, 1)
        expect(abs((sprint.position.x - 500) / (right.position.x - 500) - 2) < 0.01, "Shift must double walking speed")
        for key in [UInt16(1), 125] {
            var down = controlled(); down.facing = .left; down.pressKey(key); advance(&down, 0.1)
            expect(down.facing == .front && down.onGround && down.position.x == 500, "S and Down face the viewer without vertical movement")
            down.pressKey(2); advance(&down, 0.1)
            expect(down.facing == .front && down.position.x > 500, "Down must override simultaneous sideways movement")
            down.releaseKey(key); down.releaseKey(2); advance(&down, 0.2)
            expect(down.facing == .front, "Releasing Down must retain the front pose")
            down.pressKey(0); advance(&down, 0.2)
            expect(down.facing == .left, "A new direction must release the front-facing lock")
        }
        var airborneDown = controlled(); airborneDown.position.y = 300; airborneDown.velocity = CGVector(dx: 900, dy: 200)
        airborneDown.pressKey(125); advance(&airborneDown, 0.2)
        expect(airborneDown.facing == .front && !airborneDown.isWalking, "Down must face the viewer during a throw or jump")
        for x in [CGFloat(1516), -76] {
            var wrap = controlled(); wrap.position = CGPoint(x: x, y: 250); wrap.velocity = CGVector(dx: x > 0 ? 600 : -600, dy: 0)
            wrap.step(1.0 / 30)
            expect(wrap.wrapCount == 1 && (x > 0 ? wrap.position.x < 50 : wrap.position.x > 1390), "Crossing either edge must wrap")
            expect((x > 0 ? wrap.velocity.dx > 0 : wrap.velocity.dx < 0) && wrap.position.y > 240, "Wrapping must preserve direction and aerial height")
        }
        var negative = controlled(); negative.bounds = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        negative.position = CGPoint(x: -1997, y: -200); negative.keys = [0]; negative.step(1.0 / 30)
        expect(negative.position.x > -50 && negative.position.y == -200, "Wrapping and the floor must support negative-origin displays")
        var jump = controlled(); expect(jump.jump(), "Ground jump must be accepted")
        jump.step(1.0 / 60)
        expect(jump.onGround && jump.jumpPreparation > 0, "Jump must anticipate before leaving the floor")
        var peak: CGFloat = 0; var landing = false
        for _ in 0..<180 {
            jump.step(1.0 / 60); peak = max(peak, jump.jumpHeight)
            if jump.landingTime > 0 { landing = true }
            if jump.jumpHeight > 1 { expect(!jump.isWalking, "Airborne poses must not walk") }
        }
        expect(peak > 350 && peak < 385, "High jump must rise about 370 screen points, not an internal sprite offset")
        expect(jump.onGround && jump.velocity.dy == 0 && landing, "Jump must land exactly on the floor with compression")
        expect(abs(jump.panelOrigin.y + jump.footInset - jump.floorY) < 0.001, "Panel placement must keep the feet anchored")
        var doubleJump = controlled(); doubleJump.jump(); advance(&doubleJump, 0.55)
        let height = doubleJump.jumpHeight
        expect(doubleJump.jump() && !doubleJump.jump(), "Allow exactly one extra jump in midair")
        advance(&doubleJump, 0.45)
        expect(doubleJump.jumpHeight > height + 250, "Second jump must provide a substantial extra boost")
        advance(&doubleJump, 3)
        expect(doubleJump.jumpsUsed == 0 && doubleJump.jump(), "Landing must recharge jumping")
        var fall = controlled(); fall.position.y = 500; advance(&fall, 2)
        expect(fall.onGround && !fall.isWalking, "An unsupported pet must fall, never stand in midair")
        var roaming = controlled(); roaming.setMode(.roaming); roaming.nextDecision = 100; advance(&roaming, 1)
        expect(roaming.onGround && roaming.position.x > 530, "Autonomous roaming must stay on the floor")
        var hover = controlled(); hover.setMode(.roaming); hover.isHovered = true; advance(&hover, 0.5)
        expect(hover.position.x == 500, "Hovering a grounded roaming pet should make him easy to catch")
        hover.position.y = 300; advance(&hover, 0.1)
        expect(hover.position.y < 300, "Hover must not suspend gravity")
        var toss = controlled(); toss.beginDrag(at: 0)
        for i in 1...12 {
            let t = Double(i) / 60
            toss.drag(to: CGPoint(x: 500 + t * 1300, y: t * 1700), at: t)
            toss.step(1.0 / 60)
        }
        expect(toss.position.y > 150 && toss.position.y < 340, "Drag should follow the pointer with a spring")
        expect(!toss.isWalking, "Held pet must use a dangling pose")
        toss.endDrag(at: 0.201)
        expect(toss.velocity.dx > 1000 && toss.velocity.dy > 1300 && toss.isThrown, "Release must retain flick velocity")
        let release = toss.position; let momentum = toss.velocity
        toss.setMode(.roaming)
        expect(toss.velocity == momentum, "Losing keyboard focus must preserve throw momentum")
        toss.step(1.0 / 60)
        expect(toss.position.x > release.x && toss.position.y > release.y, "Released pet must continue flying")
        var bounced = false
        for _ in 0..<360 { toss.step(1.0 / 60); if toss.landingTime > 0 && toss.velocity.dy > 0 { bounced = true } }
        expect(bounced && toss.onGround, "Throw must bounce, lose energy, and return to the floor")
        var drop = controlled(); drop.beginDrag(at: 0); drop.drag(to: CGPoint(x: 700, y: 400), at: 0.02); advance(&drop, 1)
        drop.endDrag(at: 1)
        expect(hypot(drop.velocity.dx, drop.velocity.dy) < 1, "Holding still before release must drop without an old flick")
        advance(&drop, 4)
        expect(drop.onGround, "A stationary release must still fall")
        var fast = controlled(); fast.beginDrag(at: 0); fast.drag(to: CGPoint(x: 9500, y: 5000), at: 0.01); fast.endDrag(at: 0.011)
        expect(hypot(fast.velocity.dx, fast.velocity.dy) <= PetModel.maximumThrowSpeed + 0.01, "Extreme pointer events must have a bounded throw speed")
        var flick = controlled(); flick.beginDrag(at: 0)
        flick.drag(to: CGPoint(x: 700, y: 400), at: 0.003); flick.endDrag(at: 0.007)
        expect(flick.velocity.dx > 500 && flick.velocity.dy > 1000, "A sub-frame flick must throw without waiting for a simulation tick")
        var sparse = controlled(); sparse.beginDrag(at: 0)
        sparse.drag(to: CGPoint(x: 700, y: 300), at: 0.3); sparse.endDrag(at: 0.303)
        expect(sparse.velocity.dx > 100 && sparse.velocity.dy > 100, "Sparse pointer events must retain the gesture's starting sample")
        for key in [UInt16(1), 125] {
            var quickTurn = controlled(); quickTurn.pressKey(key); quickTurn.releaseKey(key)
            quickTurn.pressKey(2); advance(&quickTurn, 1)
            expect(quickTurn.facing == .right, "A completed Down tap must not override a newer horizontal press")
            quickTurn.pressKey(key); quickTurn.pressKey(0); advance(&quickTurn, 0.1)
            expect(quickTurn.facing == .front, "A held Down still takes priority over newer horizontal input")
        }
        var paused = controlled(); paused.position.y = 300; paused.setMode(.paused); advance(&paused, 2)
        expect(paused.onGround && !paused.isWalking, "A nap requested in midair must settle on the floor")
        expect(!paused.jump(), "A sleeping pet should not jump")
        var portal = controlled(); expect(portal.portal(to: CGPoint(x: 700, y: 400)), "An idle grounded pet must accept a portal"); advance(&portal, 0.3)
        expect(portal.position.x == 500, "Portal must wait until its midpoint")
        expect(!portal.portal(to: CGPoint(x: 900, y: 0)) && portal.portalDestination == CGPoint(x: 700, y: 0), "A portal already in progress must refuse a second request without changing course")
        advance(&portal, 0.7)
        expect(portal.position == CGPoint(x: 700, y: 0) && portal.portalTime == 0, "Portal destination must be grounded")
        expect(portal.portal(to: CGPoint(x: 300, y: 0)), "A finished portal must allow the next one")
        var held = controlled(); held.beginDrag(at: 0)
        expect(!held.portal(to: CGPoint(x: 700, y: 0)) && held.isDragging, "A pet held by the pointer cannot be summoned away")
        var sleeping = controlled(); sleeping.keys = [2]; sleeping.step(100)
        expect(sleeping.position.x < 508, "Wake from sleep must not integrate an unbounded frame")
        right.releaseKey(2); let stop = right.position.x; advance(&right, 0.5)
        expect(right.velocity == .zero && right.position.x - stop < 10 && right.phase == 0, "Walking release must settle promptly with planted feet")
        var tap = controlled(); tap.pressKey(2); tap.releaseKey(2); advance(&tap, 0.5)
        expect(tap.position.x > 503 && tap.position.x < 510, "A key tap between display frames must still register")
        tap.pressKey(2); tap.setMode(.roaming)
        expect(tap.keys.isEmpty && tap.minimumKeyTime.isEmpty, "Focus changes must clear held and buffered input")
        var lowFPS = controlled(); lowFPS.jump(); var highFPS = lowFPS
        advance(&lowFPS, 0.5, fps: 30); advance(&highFPS, 0.5, fps: 120)
        expect(abs(lowFPS.jumpHeight - highFPS.jumpHeight) < 20, "Jump height must remain consistent across frame rates")

        expect(CharacterCatalog.all.map(\.id) == ["rat-suit-rick"],"Rat Suit Rick must be the only available character")
        expect(CharacterCatalog.defaultCharacter.id == "rat-suit-rick","A fresh pet must use Rat Suit Rick")
        let freshPet = PetModel()
        expect(abs(freshPet.size.width - 135.68) < 0.000001 && abs(freshPet.size.height - 180.2) < 0.000001,"A fresh model must use Tiny at scale 0.53")
        expect(CharacterCatalog.resolve(nil) == CharacterCatalog.defaultCharacter,"Missing saved characters must use the default")
        expect(CharacterCatalog.resolve("unknown") == CharacterCatalog.defaultCharacter,"Unknown saved characters must fall back safely")
        for id in ["pickle-rick", "peon", "glados", "sc_tank"] {
            expect(CharacterCatalog.resolve(id).id == "rat-suit-rick","Retired selection \(id) must resolve to Rat Suit Rick")
        }
        for character in CharacterCatalog.all {
            expect(CharacterCatalog.resolve(character.id) == character,"Every available character must survive a saved-selection round trip")
        }
        let displays=[DesktopSurface(frame:CGRect(x:0,y:0,width:1000,height:800)),DesktopSurface(frame:CGRect(x:1000,y:0,width:1200,height:1000))]
        do {
            var seam=controlled(); seam.configureDesktop(displays)
            seam.position=CGPoint(x:950,y:0); seam.pressKey(2); advance(&seam,1)
            expect(seam.position.x>1080 && seam.activeSurface==1 && seam.wrapCount==0,"Cross the internal monitor seam without wrapping or stopping")
            expect(seam.onGround,"Cross-monitor floor travel remains grounded")
            seam.releaseKey(2); seam.pressKey(0); advance(&seam,1.5)
            expect(seam.position.x<1000 && seam.activeSurface==0 && seam.wrapCount==0,"Return freely across a monitor seam")
            seam.position=CGPoint(x:2276,y:200); seam.velocity=CGVector(dx:900,dy:0);seam.keys.removeAll();seam.minimumKeyTime.removeAll();seam.step(1.0/30)
            expect(seam.wrapCount==1 && seam.position.x<50 && seam.velocity.dx>0,"Wrap only at the far outside of the combined desktop")
        }
        var unequal=controlled(); unequal.configureDesktop([displays[0],DesktopSurface(frame:CGRect(x:1000,y:200,width:800,height:800))]);unequal.position=CGPoint(x:980,y:0)
        unequal.pressKey(2);advance(&unequal,0.5)
        expect(unequal.activeSurface==1 && unequal.position.y==200 && unequal.onGround,"Different-height monitor floors must provide a visible continuous route")
        unequal.releaseKey(2);unequal.pressKey(0);advance(&unequal,1)
        expect(unequal.activeSurface==0 && unequal.position.y==0,"Crossing back to a lower monitor must not leave Rick stranded in midair")
        var seamAir=controlled();seamAir.configureDesktop(displays);seamAir.position=CGPoint(x:990,y:400);seamAir.velocity=CGVector(dx:1000,dy:200)
        seamAir.step(1.0/30)
        expect(seamAir.activeSurface==1 && seamAir.position.y>400 && seamAir.velocity.dx>900 && seamAir.wrapCount==0,"An airborne throw crosses monitor seams with momentum and world height")
        var negativeWorld=controlled();negativeWorld.configureDesktop([DesktopSurface(frame:CGRect(x:-1920,y:0,width:1920,height:1080)),displays[0]])
        negativeWorld.position=CGPoint(x:-10,y:0);negativeWorld.pressKey(2);advance(&negativeWorld,0.3)
        expect(negativeWorld.position.x>0 && negativeWorld.wrapCount==0,"Left-side external monitors share the same continuous desktop")
        var portalAcross=controlled();portalAcross.configureDesktop(displays);portalAcross.portal(to:CGPoint(x:1800,y:500));advance(&portalAcross,1)
        expect(portalAcross.activeSurface==1 && portalAcross.position==CGPoint(x:1800,y:0),"Portal destinations can use any monitor's floor")
        var draggedAcross=controlled();draggedAcross.configureDesktop(displays);draggedAcross.beginDrag(at:0);draggedAcross.drag(to:CGPoint(x:1500,y:400),at:0.1);advance(&draggedAcross,1)
        expect(draggedAcross.activeSurface==1 && draggedAcross.position.x>1450,"Dragging can cross monitors without changing world bounds")
        draggedAcross.endDrag(at:1.1);advance(&draggedAcross,3)
        expect(draggedAcross.onGround && draggedAcross.bounds.width==2200,"A released cross-monitor drag lands in the shared world")
        draggedAcross.configureDesktop([displays[0]])
        expect(draggedAcross.position.x<=1000 && draggedAcross.onGround,"Removing an external display must rescue Rick")
        let verticallyStacked=[DesktopSurface(frame:CGRect(x:0,y:0,width:1000,height:800)),DesktopSurface(frame:CGRect(x:0,y:800,width:1000,height:800))]
        var vertical=controlled();vertical.configureDesktop(verticallyStacked);vertical.position=CGPoint(x:500,y:790);vertical.velocity=CGVector(dx:0,dy:900);vertical.step(1.0/30)
        expect(vertical.activeSurface==1 && vertical.position.y>800 && vertical.velocity.dy>0,"A throw can enter a monitor above the first")
        vertical.position=CGPoint(x:500,y:800);vertical.velocity = .zero;advance(&vertical,1.5)
        expect(vertical.position.y==0 && vertical.onGround,"An internal horizontal monitor seam must never become an invisible floor")
        vertical.placeOnGround(near:CGPoint(x:500,y:1200))
        expect(vertical.position.y==0,"Summoning must use the same bottom of the combined desktop")
        var gap=controlled();gap.configureDesktop([displays[0],DesktopSurface(frame:CGRect(x:1200,y:0,width:1000,height:800))]);gap.position=CGPoint(x:990,y:0)
        gap.pressKey(2);advance(&gap,0.3);gap.releaseKey(2);advance(&gap,0.3)
        expect(gap.position.x>=1200 && gap.onGround,"A disconnected desktop gap cannot strand the character off-screen")
        gap.pressKey(0);advance(&gap,0.6)
        expect(gap.position.x<1000 && gap.onGround,"Crossing a disconnected gap in reverse returns to visible floor")
        print("Passed \(checks) checks: grounded movement, facing, wrapping, high/double jumps, gravity, spring dragging, throws, focus, bounce, pause, portals, displays, and frame timing.")
    }
}
