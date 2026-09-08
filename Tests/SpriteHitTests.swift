import AppKit

@main
enum SpriteHitTests {
    static func main() {
        let started=ProcessInfo.processInfo.systemUptime
        var checks=0
        var poses:[(String,PetModel)]=[]
        for facing in [PetFacing.front,.left,.right,.back] {
            var idle=PetModel()
            idle.setMode(.controlled)
            idle.facing=facing
            idle.age=1.2
            poses.append(("\(facing.rawValue) idle",idle))
            for frame in 0..<4 {
                var walking=idle
                walking.velocity.dx=150
                walking.phase=CGFloat(frame) * .pi / 2
                poses.append(("\(facing.rawValue) walk \(frame)",walking))
            }
            var jumping=idle
            jumping.position.y=180
            poses.append(("\(facing.rawValue) jumping",jumping))
            var dragging=jumping
            dragging.beginDrag(at:0)
            poses.append(("\(facing.rawValue) dragging",dragging))
            var crouching=idle
            crouching.jumpPreparation=0.05
            poses.append(("\(facing.rawValue) crouching",crouching))
            var landing=idle
            landing.landingTime=0.11
            poses.append(("\(facing.rawValue) landing",landing))
            var turning=idle
            turning.turnTime=0.065
            poses.append(("\(facing.rawValue) turning",turning))
            var portal=idle
            portal.portalTime=0.6
            poses.append(("\(facing.rawValue) portal",portal))
        }
        var glance=PetModel()
        glance.idleTime=2
        glance.age=7
        poses.append(("roaming glance",glance))
        var invisible=PetModel()
        invisible.portalTime=0.425
        poses.append(("portal midpoint",invisible))

        for reducedMotion in [false,true] {
            for (label,model) in poses {
                let bitmap=render(model,reducedMotion:reducedMotion)
                var visible=0
                for y in stride(from:0,to:340,by:8) {
                    for x in stride(from:0,to:256,by:8) {
                        let alpha=bitmap.colorAt(x:x,y:y)!.alphaComponent
                        let point=CGPoint(x:CGFloat(x)+0.5,y:CGFloat(y)+0.5)
                        let hit=PetRenderer.contains(point,model:model,reducedMotion:reducedMotion)
                        if alpha==0 {
                            precondition(!hit,"\(label) intercepts transparent pixel \(point)")
                            checks += 1
                        } else if alpha>(model.portalTime>0 ? 0.2 : 0.95) {
                            precondition(hit,"\(label) ignores visible pixel \(point)")
                            visible += 1
                            checks += 1
                        }
                    }
                }
                if label != "portal midpoint" { precondition(visible>0,"Empty fixture: \(label)") }
                for point in [CGPoint(x:-1,y:200),CGPoint(x:256,y:200),CGPoint(x:128,y:-1),CGPoint(x:128,y:340)] {
                    precondition(!PetRenderer.contains(point,model:model,reducedMotion:reducedMotion))
                }
            }
        }
        // Actual defects from the old fixed rectangles, away from antialiased edges.
        let front=PetModel()
        precondition(PetRenderer.contains(CGPoint(x:70.5,y:160.5),model:front,reducedMotion:true))
        precondition(!PetRenderer.contains(CGPoint(x:114.5,y:88.5),model:front,reducedMotion:true))
        precondition(!PetRenderer.contains(CGPoint(x:128,y:325),model:front),"The ground shadow must pass clicks through")
        let elapsed=String(format:"%.2f",ProcessInfo.processInfo.systemUptime-started)
        print("Passed \(checks) sprite hit checks across \(poses.count) poses with normal and reduced motion, including invisible portals and click-through shadows, in \(elapsed) seconds.")
    }

    static func render(_ model:PetModel,reducedMotion:Bool)->NSBitmapImageRep {
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:256,pixelsHigh:340,bitsPerSample:8,
                                    samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,
                                    bytesPerRow:0,bitsPerPixel:0)!
        let context=NSGraphicsContext(bitmapImageRep:bitmap)!.cgContext
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        context.translateBy(x:0,y:340)
        context.scaleBy(x:1,y:-1)
        NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:true)
        PetRenderer.draw(in:CGRect(x:0,y:0,width:256,height:340),character:model.character,
                         phase:model.phase,walking:model.isWalking,age:model.age,jump:model.jumpHeight,
                         mode:model.mode,portal:model.portalTime>0 ? model.portalProgress : nil,
                         reducedMotion:reducedMotion,facing:model.facing,
                         anticipation:CGFloat(model.jumpPreparation),landing:CGFloat(model.landingTime),
                         turn:CGFloat(model.turnTime),idleTime:model.idleTime,dragging:model.isDragging,
                         worldPositioned:true,frontLocked:model.frontLocked,includeEffects:false)
        return bitmap
    }
}
