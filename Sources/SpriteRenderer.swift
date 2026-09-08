import AppKit
import ImageIO

// Directional Pocket Mortys poses, kept in their original, unmodified atlas.
// Attribution and frame coordinates are documented in assets/ATTRIBUTION.md.
enum PetRenderer {
    static let ink = NSColor(hex:0x14251b)
    private static let artwork = Dictionary(uniqueKeysWithValues: CharacterCatalog.all.map { ($0.id,CharacterArtwork($0)) })
    static func art(for character: CharacterDefinition) -> CharacterArtwork { artwork[character.id] ?? CharacterArtwork(character) }
    static func hasArtwork(for character: CharacterDefinition) -> Bool { art(for:character).isLoaded }

    static func ellipse(_ rect:NSRect,_ fill:NSColor,stroke:NSColor? = ink,width:CGFloat = 2.8) {
        let p=NSBezierPath(ovalIn:rect);fill.setFill();p.fill()
        if let stroke { stroke.setStroke();p.lineWidth=width;p.stroke() }
    }
    static func path(_ commands:(NSBezierPath)->Void,fill:NSColor? = nil,stroke:NSColor? = ink,width:CGFloat=2.8) {
        let p=NSBezierPath();p.lineCapStyle = .round;p.lineJoinStyle = .round
        commands(p)
        if let fill { fill.setFill();p.fill() }
        if let stroke { stroke.setStroke();p.lineWidth=width;p.stroke() }
    }

    static func draw(in rect:CGRect,character:CharacterDefinition = CharacterCatalog.defaultCharacter,phase:CGFloat=0,walking:Bool=false,
                     age:Double=0,jump:CGFloat=0,mode:PetMode = .roaming,portal:CGFloat?=nil,
                     speech:String?=nil,focused:Bool=false,reducedMotion:Bool=false,
                     facing:PetFacing?=nil,anticipation:CGFloat=0,
                     landing:CGFloat=0,turn:CGFloat=0,idleTime:Double=0,dragging:Bool=false,
                     worldPositioned:Bool=false,frontLocked:Bool=false,includeEffects:Bool=true) {
        let artwork=art(for:character)
        guard artwork.isLoaded,let ctx=NSGraphicsContext.current?.cgContext else {
            if includeEffects { drawSpeech(character.name,in:rect) }
            return
        }
        var direction=facing ?? .front
        // Short, occasional glances punctuate a rest without constantly twitching.
        let idleCycle=age.truncatingRemainder(dividingBy:9)
        if idleTime>0.8 && mode == .roaming && !dragging && jump == 0 && !frontLocked {
            direction=idleCycle>6.8 && idleCycle<7.65 ? .left : .front
        }
        let row=direction == .back ? 2 : (direction == .front ? 0 : 1)
        var frame=walking ? Int(floor(phase/(2 * .pi)*4)) % 4 : 0
        if jump>4 || dragging { frame=direction == .front ? 3 : 1 }
        let sprite=artwork.frames[row][max(0,frame)]
        ctx.saveGState()
        ctx.translateBy(x:rect.minX,y:rect.minY)
        ctx.scaleBy(x:rect.width/256,y:rect.height/340)
        ctx.interpolationQuality = .high
        let lift:CGFloat=worldPositioned ? 0 : min(60,jump)
        let breath=reducedMotion ? 0 : sin(age*2.35)*0.005
        let impact=sin(min(1,landing/0.22) * .pi)
        let crouch=anticipation>0 ? sin((1-anticipation/0.10) * .pi/2) : 0
        let airborne=jump>0 ? min(1,jump/28) : 0
        let stretchX:CGFloat=1 + impact*0.12 + crouch*0.10 - airborne*0.045
        let stretchY:CGFloat=1 - impact*0.11 - crouch*0.10 + airborne*0.055 + breath
        let shadowWidth:CGFloat=108-lift*0.65
        // Soft, concentric contact shadow stays on the ground during jumps.
        for i in (0...5).reversed() where includeEffects && (!worldPositioned || (jump < 2 && !dragging)) {
            let spread=CGFloat(i)*2.2
            ellipse(NSRect(x:128-shadowWidth/2-spread,y:318-spread*0.27,width:shadowWidth+spread*2,height:7+spread*0.55),
                    NSColor.black.withAlphaComponent(0.024*(1-lift/95)),stroke:nil)
        }
        if includeEffects && focused && jump < 2 && !dragging {
            path({$0.appendOval(in:NSRect(x:71,y:313,width:114,height:11))},stroke:NSColor(hex:0xb0ee72).withAlphaComponent(0.55),width:1.3)
        }
        if includeEffects && landing>0 && jump < 10 && !dragging && !reducedMotion {
            let t=1-landing/0.22
            for i in 0..<6 {
                let sign:CGFloat=i<3 ? -1 : 1
                let x=128+sign*(30+t*45+CGFloat(i%3)*10)
                ellipse(NSRect(x:x,y:315-t*CGFloat(9+i%3*4),width:3-t*2,height:2-t),NSColor(hex:0xc9d4b7).withAlphaComponent((1-t)*0.4),stroke:nil)
            }
        }
        if let portal {
            if includeEffects { drawPortal(ctx,progress:portal,age:age) }
            let visibility=max(0,min(1,abs(portal-0.5)*2.4))
            ctx.setAlpha(visibility)
            let squeeze=max(0.015,visibility)
            ctx.translateBy(x:128*(1-squeeze),y:0);ctx.scaleBy(x:squeeze,y:1)
        }
        ctx.translateBy(x:128,y:319-lift+character.sprites.footCorrections[row][max(0,frame)])
        // The authored walk poses supply the weight shift. Additional rotation or
        // vertical bobbing would move their planted feet below the desktop floor.
        let lean:CGFloat = reducedMotion ? 0 : (dragging ? sin(age*6)*0.025 : 0)
        ctx.rotate(by:lean)
        let turnScale:CGFloat=1-(turn>0 ? sin((1-turn/0.13) * .pi)*0.10 : 0)
        ctx.scaleBy(x:stretchX*turnScale,y:stretchY)
        if direction == .right { ctx.scaleBy(x:-1,y:1) }
        // Every crop has the same cell size and foot baseline; changing poses never jitters the rig.
        let destination=CGRect(x:-100,y:-256,width:200,height:256)
        ctx.translateBy(x:destination.minX,y:destination.maxY)
        ctx.scaleBy(x:1,y:-1)
        ctx.draw(sprite,in:CGRect(x:0,y:0,width:destination.width,height:destination.height))
        ctx.restoreGState()
        if includeEffects {
            if let speech { drawSpeech(speech,in:rect) }
            else if mode == .paused { drawSpeech("Z z z",in:rect) }
        }
    }

    static func contains(_ point:CGPoint,model:PetModel,reducedMotion:Bool=false) -> Bool {
        guard CGRect(x:0,y:0,width:256,height:340).contains(point),art(for:model.character).isLoaded else { return false }
        // Sample the actual animated body under the pointer. Decorations never capture clicks.
        var pixel=[UInt8](repeating:0,count:4)
        pixel.withUnsafeMutableBytes { bytes in
            guard let context=CGContext(data:bytes.baseAddress,width:1,height:1,bitsPerComponent:8,
                                        bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:true)
            context.translateBy(x:0.5-point.x,y:0.5+point.y)
            context.scaleBy(x:1,y:-1)
            draw(in:CGRect(x:0,y:0,width:256,height:340),character:model.character,phase:model.phase,
                 walking:model.isWalking,age:model.age,jump:model.jumpHeight,mode:model.mode,
                 portal:model.portalTime>0 ? model.portalProgress : nil,reducedMotion:reducedMotion,
                 facing:model.facing,anticipation:CGFloat(model.jumpPreparation),
                 landing:CGFloat(model.landingTime),turn:CGFloat(model.turnTime),idleTime:model.idleTime,
                 dragging:model.isDragging,worldPositioned:true,frontLocked:model.frontLocked,includeEffects:false)
        }
        return pixel[3]>16
    }

    static func drawPortal(_ ctx:CGContext,progress:CGFloat,age:Double) {
        let open=pow(sin(progress * .pi),0.65)
        ctx.saveGState();ctx.translateBy(x:128,y:207);ctx.scaleBy(x:max(0.03,open),y:max(0.03,open))
        for i in (0..<7).reversed() {
            let spread=CGFloat(i)*3
            ellipse(NSRect(x:-64-spread,y:-116-spread,width:128+spread*2,height:232+spread*2),NSColor(hex:0x7efa45).withAlphaComponent(0.022),stroke:nil)
        }
        ellipse(NSRect(x:-62,y:-113,width:124,height:226),NSColor(hex:0x255d26).withAlphaComponent(0.96),stroke:NSColor(hex:0xd4ff79),width:4)
        for i in 0..<9 {
            let radius=8+CGFloat(i)*5.8
            path({p in
                for j in 0...64 {
                    let angle=CGFloat(j)/64*2 * .pi
                    let ripple=1+sin(angle*4+CGFloat(age)*5+CGFloat(i))*0.055
                    let q=CGPoint(x:cos(angle)*radius*ripple,y:sin(angle)*radius*1.75*ripple)
                    if j==0 {p.move(to:q)} else {p.line(to:q)}
                }
            },stroke:NSColor(hex:i%2==0 ? 0xb6ee69 : 0x5fad33).withAlphaComponent(0.72),width:2.5)
        }
        for i in 0..<14 {
            let a=CGFloat(i)/14 * 2 * .pi + CGFloat(age)*0.7
            let r=CGFloat(66+(i%3)*5)
            ellipse(NSRect(x:cos(a)*r-1.8,y:sin(a)*r*1.68-1.8,width:3.6,height:3.6),NSColor(hex:0xd9ffa2).withAlphaComponent(0.8),stroke:nil)
        }
        ctx.restoreGState()
    }

    static func drawSpeech(_ text: String, in rect: CGRect) {
        let font = NSFont.systemFont(ofSize: max(10,min(12,rect.width/17)),weight:.semibold)
        let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center;paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:NSColor(hex:0xe6f4db),.paragraphStyle:paragraph]
        // Drawing must use the same line layout as measurement, including the final wrapped line.
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let measured=(text as NSString).boundingRect(with:NSSize(width:max(40,rect.width-28),height:100),options:options,attributes:attrs)
        let size=NSSize(width:ceil(measured.width),height:ceil(measured.height))
        let bubble = NSRect(x:rect.midX-size.width/2-11,y:rect.minY+5,width:size.width+22,height:size.height+14)
        let shadow=NSShadow();shadow.shadowColor=NSColor.black.withAlphaComponent(0.18);shadow.shadowBlurRadius=8;shadow.shadowOffset=NSSize(width:0,height:2)
        NSGraphicsContext.saveGraphicsState();shadow.set()
        let p=NSBezierPath(roundedRect:bubble,xRadius:10,yRadius:10);NSColor(hex:0x19271e).setFill();p.fill()
        NSGraphicsContext.restoreGraphicsState()
        (text as NSString).draw(with:NSRect(x:bubble.minX+11,y:bubble.minY+7,width:size.width,height:size.height),options:options,attributes:attrs)
    }

    static func drawIcon() {
        let outline=NSBezierPath(roundedRect:NSRect(x:42,y:42,width:940,height:940),xRadius:210,yRadius:210)
        NSColor(hex:0x17221b).setFill();outline.fill()
        // The large front portrait above the animation frames excludes the atlas gutters.
        guard let portrait=art(for:CharacterCatalog.ratSuit).atlas?.cropping(to:CGRect(x:5,y:5,width:634,height:730)),
              let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        outline.addClip()
        context.interpolationQuality = .high
        let destination=CGRect(x:120,y:90,width:784,height:903)
        context.translateBy(x:destination.minX,y:destination.maxY)
        context.scaleBy(x:1,y:-1)
        context.draw(portrait,in:CGRect(origin:.zero,size:destination.size))
        context.restoreGState()
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed:CGFloat((hex >> 16) & 255)/255,green:CGFloat((hex >> 8) & 255)/255,blue:CGFloat(hex & 255)/255,alpha:1)
    }
}
