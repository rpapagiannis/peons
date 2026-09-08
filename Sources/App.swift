import AppKit
import SwiftUI

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    // The body must be able to leave an edge before wrapping to the other side.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class SeamPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect:NSRect,to screen:NSScreen?) -> NSRect { frameRect }
}

final class PetView: NSView {
    weak var owner: PetController?
    var canvasRect: CGRect?
    var rendersCharacter = true
    private var dragStart: CGPoint?
    private var initialPosition = CGPoint.zero
    private var dragStartTime = 0.0
    private var dragged = false
    var hasPointerCapture: Bool { dragStart != nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { false }
    override func accessibilityPerformPress() -> Bool { owner?.takeControl(); return true }

    override func draw(_ dirtyRect: NSRect) {
        guard let owner else { return }
        NSColor.clear.setFill(); bounds.fill(using:.copy)
        guard rendersCharacter else { return }
        NSGraphicsContext.saveGraphicsState()
        bounds.clip()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let model = owner.model
        PetRenderer.draw(in: canvasRect ?? bounds, character:model.character,phase:model.phase, walking:model.isWalking,
                          age:model.age, jump:model.jumpHeight,
                          mode:model.mode, portal:model.portalTime > 0 ? model.portalProgress : nil,
                          speech:owner.speech, focused:model.mode == .controlled,
                          reducedMotion:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                          facing:model.facing,anticipation:CGFloat(model.jumpPreparation),
                          landing:CGFloat(model.landingTime),turn:CGFloat(model.turnTime),
                          idleTime:model.idleTime,dragging:model.isDragging,
                          worldPositioned:true,frontLocked:model.frontLocked)
    }

    override func mouseDown(with event: NSEvent) {
        guard let owner else { return }
        if event.modifierFlags.contains(.control) { rightMouseDown(with:event); return }
        dragStart = NSEvent.mouseLocation
        initialPosition = owner.model.position
        dragStartTime = event.timestamp
        dragged = false
        owner.takeControl()
        if event.clickCount == 2 { owner.jump() }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let owner, let dragStart else { return }
        let mouse = NSEvent.mouseLocation
        if !dragged {
            guard hypot(mouse.x-dragStart.x,mouse.y-dragStart.y) >= 10 else { return }
            dragged = true
            owner.model.beginDrag(at:dragStartTime,from:initialPosition)
        }
        owner.model.drag(to:CGPoint(x:initialPosition.x+mouse.x-dragStart.x,y:initialPosition.y+mouse.y-dragStart.y),at:event.timestamp)
    }
    override func mouseUp(with event: NSEvent) {
        if dragged {
            owner?.model.endDrag(at:event.timestamp)
            owner?.say(.toss,for:1.5)
        }
        dragStart = nil
        dragged = false
    }
    override func rightMouseDown(with event: NSEvent) {
        guard let owner else { return }
        NSMenu.popUpContextMenu(owner.makeMenu(),with:event,for:self)
    }
    override func keyDown(with event: NSEvent) {
        guard let owner else { return }
        synchronizeShift(with:event.modifierFlags)
        // Command shortcuts must retain their normal macOS meaning.
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "q" { NSApp.terminate(nil) }
            return
        }
        switch event.keyCode {
        case 53: owner.roam()
        case 49,13,126: if !event.isARepeat { owner.jump() }
        case 35: if !event.isARepeat { owner.portal() }
        case 14: if !event.isARepeat { owner.shout() }
        case 46: if !event.isARepeat { owner.toggleSound() }
        case 4,8: if !event.isARepeat { owner.showControls() }
        case 0,1,2,123,124,125:
            owner.model.pressKey(event.keyCode)
            if !event.isARepeat { owner.say(.move) }
        default: break
        }
    }
    override func keyUp(with event: NSEvent) {
        synchronizeShift(with:event.modifierFlags)
        owner?.model.releaseKey(event.keyCode)
    }
    override func flagsChanged(with event: NSEvent) {
        synchronizeShift(with:event.modifierFlags)
    }
    private func synchronizeShift(with flags:NSEvent.ModifierFlags) {
        // Key events include modifiers held before focus; AppKit may never send their initial flagsChanged.
        // Track the aggregate Shift flag so releasing either Shift while the other is held keeps sprinting.
        owner?.model.keys.remove(56)
        owner?.model.keys.remove(60)
        if flags.contains(.shift) { owner?.model.keys.insert(56) }
    }
}

final class PetController: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, ObservableObject {
    var model = PetModel()
    var panel: PetPanel!
    var petView: PetView!
    var seamPanels: [String:SeamPanel] = [:]
    var hasPointerCapture: Bool { petView.hasPointerCapture || seamPanels.values.contains { ($0.contentView as? PetView)?.hasPointerCapture == true } }
    var statusItem: NSStatusItem!
    var controlWindow: NSWindow?
    var timer: Timer?
    var lastTime = ProcessInfo.processInfo.systemUptime
    var speech: String?
    var speechUntil: Double = 0
    var dialogue = DialogueDirector()
    let voice = VoicePlayer()
    var suppressResign = false
    var hovering = false
    var menuOpen = false
    var tickNumber = 0
    var accessibilityState = ""
    @Published var displayedMode: PetMode = .roaming
    let selectedCharacter = CharacterCatalog.ratSuit
    @Published var isHidden = false
    @Published var soundEnabled = true
    @Published var chatterEnabled = true
    @Published var volume: Double = 0.5

    func loadPreferences(from defaults:UserDefaults = .standard) {
        soundEnabled=defaults.object(forKey:"soundEnabled") as? Bool ?? true
        chatterEnabled=defaults.object(forKey:"chatterEnabled") as? Bool ?? true
        volume=min(1,max(0,defaults.object(forKey:"voiceVolume") as? Double ?? 0.5))
        model.speed = defaults.object(forKey:"speed") as? CGFloat ?? 150
        defaults.set(selectedCharacter.id,forKey:"character")
        defaults.removeObject(forKey:"size")
        model.selectCharacter(selectedCharacter)
        model.size = PetModel.desktopSize
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadPreferences()
        model.configureDesktop(desktopSurfaces())
        let startingScreen=screenAtMouse().visibleFrame
        model.placeOnGround(near:CGPoint(x:startingScreen.midX,y:startingScreen.minY+1))
        panel = PetPanel(contentRect:CGRect(origin:model.panelOrigin,size:model.size),
                         styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title = "Peons — \(selectedCharacter.name)"
        panel.identifier = NSUserInterfaceItemIdentifier("desktop-peon")
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications,.ignoresCycle]
        panel.delegate = self
        panel.isMovableByWindowBackground = false
        petView = PetView(frame:CGRect(origin:.zero,size:model.size))
        petView.owner = self
        petView.autoresizingMask = [.width,.height]
        petView.setAccessibilityElement(true)
        petView.setAccessibilityRole(.button)
        petView.setAccessibilityLabel("\(selectedCharacter.name). Click to control. Drag and release to throw. Right click for controls and options.")
        panel.contentView = petView
        placePanel()
        panel.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = menuIcon()
            button.toolTip = "Peons — Rat Suit Rick controls"
            button.setAccessibilityLabel("Peons")
        }
        statusItem.menu = makeMenu()
        NotificationCenter.default.addObserver(self,selector:#selector(screensChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(willSleep),name:NSWorkspace.willSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(didWake),name:NSWorkspace.didWakeNotification,object:nil)
        timer = Timer(timeInterval:1.0/60.0,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        timer?.tolerance = 0.002
        RunLoop.main.add(timer!,forMode:.common)
        say(.greet,for:4)
        if !UserDefaults.standard.bool(forKey:"hasLaunched") && !CommandLine.arguments.contains("--skip-welcome") {
            showControls()
            UserDefaults.standard.set(true,forKey:"hasLaunched")
        }
        writeDiagnostics()
    }

    func screenAtMouse() -> NSScreen {
        NSScreen.screens.first(where:{$0.frame.contains(NSEvent.mouseLocation)}) ?? NSScreen.main ?? NSScreen.screens[0]
    }
    func desktopSurfaces() -> [DesktopSurface] { NSScreen.screens.map { DesktopSurface(frame:$0.frame,visibleFrame:$0.visibleFrame) } }

    @objc func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now-lastTime;lastTime=now
        guard !isHidden else { return }
        if model.mode == .controlled && !panel.isKeyWindow && !hasPointerCapture && !suppressResign {
            model.setMode(.roaming);displayedMode = .roaming
        }
        let mouse = NSEvent.mouseLocation
        let canvas = CGRect(origin:model.panelOrigin,size:model.size)
        let local = CGPoint(x:(mouse.x-canvas.minX)/canvas.width*256,y:(canvas.maxY-mouse.y)/canvas.height*340)
        let overPet = PetRenderer.contains(local,model:model,reducedMotion:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        // Use only the current pointer location, with no event tap or global key listener.
        // A transparent part of the panel passes clicks straight to the app below.
        panel.ignoresMouseEvents = !overPet && !petView.hasPointerCapture && !menuOpen
        for window in seamPanels.values {
            window.ignoresMouseEvents = !overPet && (window.contentView as? PetView)?.hasPointerCapture != true && !menuOpen
        }
        hovering = (overPet || menuOpen) && model.mode == .roaming
        model.isHovered=hovering
        if !menuOpen { model.step(dt) }
        if speech != nil && now >= speechUntil { speech=nil }
        if chatterEnabled && model.mode == .roaming && !model.isDragging && !menuOpen && now>=dialogue.nextAutomaticAt { say(.idle) }
        placePanel()
        petView.needsDisplay = true
        tickNumber += 1
        if tickNumber % 6 == 0 {
            writeDiagnostics()
        }
    }

    func placePanel() {
        guard panel != nil else { return }
        let canvas=CGRect(origin:model.panelOrigin,size:model.size)
        let slices=NSScreen.screens.compactMap { screen -> (String,CanvasSlice)? in
            guard let slice=CanvasSlice.visible(canvas:canvas,display:screen.frame) else { return nil }
            return (String(describing:screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? screen.localizedName),slice)
        }
        let primary=slices.max { $0.1.windowFrame.width*$0.1.windowFrame.height < $1.1.windowFrame.width*$1.1.windowFrame.height }
        let mainSlice=primary?.1 ?? CanvasSlice(canvas:canvas,windowFrame:canvas)
        panel.setFrame(mainSlice.windowFrame,display:false)
        petView.canvasRect=mainSlice.drawingRect
        petView.needsDisplay=true
        var visibleIDs=Set<String>()
        for (id,slice) in slices where id != primary?.0 {
            visibleIDs.insert(id)
            let window:SeamPanel
            if let existing=seamPanels[id] { window=existing }
            else {
                window=SeamPanel(contentRect:slice.windowFrame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                window.backgroundColor = .clear;window.isOpaque=false;window.hasShadow=false
                window.level = .floating;window.isFloatingPanel=true;window.hidesOnDeactivate=false
                window.isReleasedWhenClosed=false
                window.collectionBehavior = panel.collectionBehavior
                let view=PetView(frame:CGRect(origin:.zero,size:slice.windowFrame.size))
                view.owner=self;view.autoresizingMask=[.width,.height]
                view.setAccessibilityElement(false)
                window.contentView=view
                seamPanels[id]=window
            }
            let view=window.contentView as! PetView
            window.setFrame(slice.windowFrame,display:false)
            view.canvasRect=slice.drawingRect;view.rendersCharacter=true;view.needsDisplay=true
            if !isHidden && !window.isVisible { window.orderFrontRegardless() }
        }
        for (id,window) in seamPanels where !visibleIDs.contains(id) {
            let view=window.contentView as! PetView
            // AppKit owns this mouse gesture until mouse-up, even after crossing a seam.
            if view.hasPointerCapture { view.rendersCharacter=false;view.needsDisplay=true }
            else { window.orderOut(nil) }
        }
    }
    func say(_ action: CharacterAction, for seconds: Double = 2) {
        guard !isHidden,model.mode != .paused else { return }
        let now=ProcessInfo.processInfo.systemUptime
        guard let line=dialogue.next(character:model.character,action:action,now:now) else { return }
        let duration=soundEnabled ? voice.play(line,volume:volume) : 0
        speech=line.text;speechUntil=now+max(seconds,duration+0.35,2)
        dialogue.occupy(until:speechUntil+0.3,now:now)
    }
    func silence() { voice.stop();speech=nil;dialogue.reset(now:ProcessInfo.processInfo.systemUptime) }
    @objc func shout() { say(.shout,for:2.5) }
    @objc func toggleSound() {
        soundEnabled.toggle();UserDefaults.standard.set(soundEnabled,forKey:"soundEnabled")
        if !soundEnabled { voice.stop() }
        writeDiagnostics()
    }
    @objc func toggleChatter() {
        chatterEnabled.toggle();UserDefaults.standard.set(chatterEnabled,forKey:"chatterEnabled")
        dialogue.rescheduleAutomatic(now:ProcessInfo.processInfo.systemUptime)
    }
    func setVolume(_ value:Double) { volume=min(1,max(0,value));voice.setVolume(volume);UserDefaults.standard.set(volume,forKey:"voiceVolume") }
    @objc func takeControl() {
        if isHidden { toggleHidden() }
        model.setMode(.controlled); displayedMode = .controlled
        panel.ignoresMouseEvents = false
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(petView)
        say(.control,for:2)
        writeDiagnostics()
    }
    @objc func roam() {
        model.setMode(.roaming);displayedMode = .roaming
        suppressResign=true
        panel.resignKey()
        suppressResign=false
        silence()
        writeDiagnostics()
    }
    @objc func togglePause() {
        let pausing = model.mode != .paused
        model.setMode(pausing ? .paused : .roaming);displayedMode=model.mode
        panel.resignKey()
        silence()
        writeDiagnostics()
    }
    @objc func jump() { if model.jump() { say(.jump,for:1.5) } }
    @objc func portal() {
        let destination=NSScreen.screens.randomElement()?.visibleFrame ?? model.bounds
        // A refused portal (one already open, or Rick held mid-drag) must not consume a voice line.
        if model.portal(to:CGPoint(x:CGFloat.random(in:destination.minX...destination.maxX),y:destination.minY+1)) { say(.portal,for:1.4) }
    }
    @objc func summon() {
        if isHidden { toggleHidden() }
        // Menu-driven summoning must not steal keyboard focus from the current app.
        if model.portal(to:NSEvent.mouseLocation) { say(.summon,for:3) }
    }
    @objc func toggleHidden() {
        isHidden.toggle()
        silence()
        model.keys.removeAll();model.velocity = .zero
        if isHidden { panel.orderOut(nil);seamPanels.values.forEach{$0.orderOut(nil)};model.setMode(.roaming);displayedMode = .roaming }
        else { placePanel();panel.orderFrontRegardless();lastTime=ProcessInfo.processInfo.systemUptime }
        writeDiagnostics()
    }
    @objc func chooseSpeed(_ sender: NSMenuItem) {
        model.speed=CGFloat(sender.tag);UserDefaults.standard.set(sender.tag,forKey:"speed")
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func screensChanged() {
        model.configureDesktop(desktopSurfaces())
        placePanel()
    }
    @objc func willSleep() { silence();timer?.fireDate = .distantFuture;model.keys.removeAll();model.minimumKeyTime.removeAll() }
    @objc func didWake() { lastTime=ProcessInfo.processInfo.systemUptime;timer?.fireDate = .distantPast;screensChanged() }

    func windowDidResignKey(_ notification: Notification) {
        guard let window=notification.object as? NSWindow,window === panel,!suppressResign else { return }
        model.keys.removeAll()
        if model.mode == .controlled { model.setMode(.roaming);displayedMode = .roaming }
    }
    func windowWillClose(_ notification: Notification) {
        if let window=notification.object as? NSWindow,window === controlWindow { controlWindow=nil }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification:Notification) { voice.stop();timer?.invalidate() }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool { showControls();return true }

    func item(_ title: String,_ action: Selector?,key: String = "") -> NSMenuItem {
        let item=NSMenuItem(title:title,action:action,keyEquivalent:key);item.target=self;return item
    }
    func makeMenu() -> NSMenu {
        let menu=NSMenu();menu.delegate=self
        populate(menu);return menu
    }
    func menuNeedsUpdate(_ menu: NSMenu) { populate(menu) }
    func menuWillOpen(_ menu:NSMenu) { menuOpen=true;model.keys.removeAll();model.minimumKeyTime.removeAll() }
    func menuDidClose(_ menu:NSMenu) { menuOpen=false }
    func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading=item("PEONS",nil);heading.isEnabled=false;menu.addItem(heading)
        menu.addItem(item("Rick controls…",#selector(showControls)))
        menu.addItem(.separator())
        let take=item("Take control · WASD / arrows",#selector(takeControl));take.state=model.mode == .controlled ? .on : .off;menu.addItem(take)
        let roaming=item("Roam freely",#selector(roam));roaming.state=model.mode == .roaming ? .on : .off;menu.addItem(roaming)
        menu.addItem(item(model.mode == .paused ? "Wake up" : "Take a nap",#selector(togglePause)))
        menu.addItem(item("Jump!",#selector(jump)))
        menu.addItem(item("Open a portal",#selector(portal)))
        menu.addItem(item("Bring Rick here",#selector(summon)))
        menu.addItem(item("Shout · E",#selector(shout)))
        menu.addItem(.separator())
        let sound=item("Voices · M to mute",#selector(toggleSound));sound.state=soundEnabled ? .on : .off;menu.addItem(sound)
        let chatter=item("Occasional chatter",#selector(toggleChatter));chatter.state=chatterEnabled ? .on : .off;menu.addItem(chatter)
        let speedMenu=NSMenu()
        for (name,value) in [("Chill",95),("Normal",150),("Unhinged",240)] {
            let choice=item(name,#selector(chooseSpeed(_:)));choice.tag=value;choice.state=Int(model.speed) == value ? .on : .off;speedMenu.addItem(choice)
        }
        let speeds=item("Speed",nil);speeds.submenu=speedMenu;menu.addItem(speeds)
        menu.addItem(item(isHidden ? "Show Rick" : "Hide Rick",#selector(toggleHidden)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Peons",#selector(quit),key:"q"))
    }

    @objc func showControls() {
        if let controlWindow { controlWindow.makeKeyAndOrderFront(nil);NSApp.activate();return }
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:748),styleMask:[.titled,.closable,.miniaturizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.title="Peons · Rick controls"
        window.titlebarAppearsTransparent=true
        window.titleVisibility = .hidden
        window.backgroundColor=NSColor(hex:0x17191f)
        window.isReleasedWhenClosed=false
        window.delegate=self
        window.contentView=NSHostingView(rootView:ControlRoom(owner:self))
        window.center();window.makeKeyAndOrderFront(nil)
        controlWindow=window
        NSApp.activate()
    }

    func menuIcon() -> NSImage {
        let image=NSImage(size:NSSize(width:18,height:21),flipped:false) { _ in
            let body=NSBezierPath(roundedRect:NSRect(x:5,y:2,width:9,height:17),xRadius:4.5,yRadius:4.5)
            NSColor.black.setFill();body.fill()
            NSGraphicsContext.current?.compositingOperation = .copy
            NSColor.clear.setFill()
            NSBezierPath(ovalIn:NSRect(x:7,y:12,width:2,height:2)).fill()
            NSBezierPath(ovalIn:NSRect(x:11,y:12,width:2,height:2)).fill()
            return true
        }
        image.isTemplate=true;return image
    }

    // Opt-in diagnostics contain only this pet's state, never screen content or input text.
    func writeDiagnostics() {
        let value="\(model.character.name); \(model.mode.rawValue)"
        if value != accessibilityState { petView?.setAccessibilityValue(value);accessibilityState=value }
        var destination=UserDefaults.standard.string(forKey:"developmentDiagnostics")
        if let index=CommandLine.arguments.firstIndex(of:"--diagnostics"),CommandLine.arguments.count>index+1 { destination=CommandLine.arguments[index+1] }
        guard let destination else { return }
        let state:[String:Any] = ["mode":model.mode.rawValue,"x":model.position.x,"y":model.position.y,
            "width":model.size.width,"height":model.size.height,"key":panel?.isKeyWindow ?? false,
            "hidden":isHidden,"walking":model.isWalking,"character":model.character.id,"keys":model.keys.sorted(),"distance":model.distance,
            "jump":model.jumpHeight,"portal":model.portalTime,"ignoresMouse":panel?.ignoresMouseEvents ?? true,
            "vx":model.velocity.dx,"vy":model.velocity.dy,"grounded":model.onGround,"dragging":model.isDragging,
            "wraps":model.wrapCount,"throw":[model.lastThrowVelocity.dx,model.lastThrowVelocity.dy],
            "panel":[panel?.frame.minX ?? 0,panel?.frame.minY ?? 0],"jumpsUsed":model.jumpsUsed,
            "facing":model.facing.rawValue,"phase":model.phase,"artwork":PetRenderer.hasArtwork(for:model.character),
            "activeSurface":model.activeSurface,"surfaces":model.surfaces.map{[$0.frame.minX,$0.frame.minY,$0.frame.width,$0.frame.height,$0.visibleFrame.minY]},
            "separateSpaces":NSScreen.screensHaveSeparateSpaces,"seamWindows":seamPanels.values.filter{$0.isVisible}.count,
            "soundEnabled":soundEnabled,"volume":volume,"chatterEnabled":chatterEnabled,"speech":speech ?? "","audioPlaying":voice.isPlaying,"audioLine":voice.playingLineID ?? "",
            "screen":[model.bounds.minX,model.bounds.minY,model.bounds.width,model.bounds.height]]
        if let data=try? JSONSerialization.data(withJSONObject:state,options:[.prettyPrinted,.sortedKeys]) {
            try? data.write(to:URL(fileURLWithPath:destination),options:.atomic)
        }
    }
}

struct CharacterPreview: NSViewRepresentable {
    let character: CharacterDefinition
    func makeNSView(context: Context) -> PreviewView { PreviewView(character:character) }
    func updateNSView(_ view: PreviewView,context: Context) { view.character=character;view.needsDisplay=true }
    final class PreviewView: NSView {
        var character:CharacterDefinition
        var timer: Timer?
        let started=ProcessInfo.processInfo.systemUptime
        init(character:CharacterDefinition) { self.character=character;super.init(frame:.zero) }
        required init?(coder:NSCoder) { fatalError("init(coder:) is not supported") }
        override var isFlipped: Bool { true }
        override func viewDidMoveToWindow() {
            timer?.invalidate();timer=nil
            if window != nil {
                let timer=Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in self?.needsDisplay=true }
                RunLoop.main.add(timer,forMode:.common);self.timer=timer
            }
        }
        override func draw(_ dirtyRect: NSRect) {
            let time=ProcessInfo.processInfo.systemUptime-started
            let reduce=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let cycle=time.truncatingRemainder(dividingBy:8)
            let moving=cycle<5 && !reduce
            PetRenderer.draw(in:bounds,character:character,
                             phase:CGFloat(time)*7,walking:moving,age:time,mode:.controlled,reducedMotion:reduce,
                             facing:moving ? .right : .front,worldPositioned:true)
        }
        deinit { timer?.invalidate() }
    }
}

struct ControlRoom: View {
    @ObservedObject var owner: PetController
    let accent=Color(red:0.77,green:0.71,blue:0.99)
    let cream=Color(red:0.94,green:0.94,blue:0.90)
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack {
                Text("PEONS")
                    .font(.system(size:11,weight:.bold,design:.monospaced)).tracking(1.6).foregroundColor(accent)
                Spacer()
                Circle().fill(owner.isHidden || owner.displayedMode == .paused ? .gray : Color.green).frame(width:5,height:5)
                Text(owner.isHidden ? "HIDDEN" : owner.displayedMode.rawValue.uppercased())
                    .font(.system(size:9,weight:.medium,design:.monospaced)).foregroundColor(.white.opacity(0.5))
            }.padding(.top,35)
            Text("Tiny Rick.\nBig attitude.")
                .font(.system(size:32,weight:.heavy,design:.rounded)).tracking(-0.9).lineSpacing(-2).foregroundColor(cream).padding(.top,24)
            Text("Your desktop. His playground.")
                .font(.system(size:13)).foregroundColor(.white.opacity(0.5)).padding(.top,8)
            HStack(spacing:20) {
                CharacterPreview(character:owner.selectedCharacter).frame(width:180,height:239)
                VStack(alignment:.leading,spacing:10) {
                    Text(owner.selectedCharacter.name).font(.system(size:24,weight:.bold,design:.rounded)).foregroundColor(cream)
                    Text(owner.selectedCharacter.collection).font(.system(size:12)).foregroundColor(.white.opacity(0.45))
                    Text("He wanders, jumps, and opens portals.\nJoin in or pick him up and throw him.")
                        .font(.system(size:13)).lineSpacing(4).foregroundColor(.white.opacity(0.65))
                    Text("TINY · WALKS")
                        .font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundColor(accent)
                        .padding(.top,5)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.padding(.horizontal,24).frame(height:278)
                .background(accent.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius:17))
                .overlay(RoundedRectangle(cornerRadius:17).stroke(accent.opacity(0.25),lineWidth:1))
                .padding(.top,23)
            HStack(spacing:10) {
                Button { owner.controlWindow?.close();owner.takeControl() } label: {
                    Label("Take control",systemImage:"gamecontroller.fill").font(.system(size:13,weight:.bold)).frame(maxWidth:.infinity).padding(.vertical,13)
                }.buttonStyle(.plain).foregroundColor(Color(red:0.13,green:0.12,blue:0.18)).background(accent).clipShape(RoundedRectangle(cornerRadius:11))
                Button { owner.roam();owner.controlWindow?.close() } label: {
                    Text("Let Rick roam").font(.system(size:13,weight:.semibold)).frame(maxWidth:.infinity).padding(.vertical,13)
                }.buttonStyle(.plain).foregroundColor(cream).background(.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius:11))
            }.padding(.top,20)
            HStack(spacing:12) {
                Button { owner.shout() } label: { Label("Shout",systemImage:"quote.bubble.fill") }
                    .buttonStyle(.plain).foregroundColor(accent)
                Text("\(owner.selectedCharacter.recordedLineCount) recorded voice lines")
                    .font(.system(size:10)).foregroundColor(.white.opacity(0.4))
                Spacer()
                Button { owner.toggleSound() } label: {
                    Image(systemName:owner.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill").frame(width:23)
                }.buttonStyle(.plain).accessibilityLabel(owner.soundEnabled ? "Mute voices" : "Unmute voices")
                Slider(value:Binding(get:{owner.volume},set:{owner.setVolume($0)}),in:0...1).frame(width:78).accessibilityLabel("Voice volume")
            }.font(.system(size:12,weight:.semibold)).padding(.top,17)
            HStack(alignment:.top,spacing:12) {
                VStack(alignment:.leading,spacing:10) {
                    key("A D / ← →","Walk · Shift to sprint")
                    key("W / ↑ / SPACE","Jump · twice for higher")
                    key("S / ↓","Face you")
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.leading,spacing:10) {
                    key("DRAG + RELEASE","Throw")
                    key("P / E / M","Portal · Shout · Mute")
                    key("ESC","Back to roaming")
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.padding(17).background(.white.opacity(0.025)).clipShape(RoundedRectangle(cornerRadius:12)).padding(.top,17)
            HStack(spacing:9) {
                Text("Right-click Rick for speed, nap, and other controls.").font(.system(size:10)).foregroundColor(.white.opacity(0.35))
                Spacer()
                Button(owner.isHidden ? "Show" : "Hide") { owner.toggleHidden() }.buttonStyle(.plain)
                Text("·").foregroundColor(.white.opacity(0.2))
                Button("Quit") { owner.quit() }.buttonStyle(.plain)
            }.font(.system(size:10)).foregroundColor(.white.opacity(0.5)).padding(.top,18)
            Spacer(minLength:20)
        }.padding(.horizontal,30).frame(width:620,height:748).background(Color(red:0.075,green:0.08,blue:0.10)).preferredColorScheme(.dark)
    }
    func key(_ title:String,_ description:String)->some View {
        HStack(spacing:7) {
            Text(title).font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundColor(accent.opacity(0.85))
            Text(description).font(.system(size:10)).foregroundColor(.white.opacity(0.5))
        }
    }
}

#if !APP_TESTS
@main
#endif
enum PeonsApp {
    static func main() {
        let characterIndex=CommandLine.arguments.firstIndex(of:"--character")
        let renderCharacter=CharacterCatalog.resolve(characterIndex.flatMap { CommandLine.arguments.count>$0+1 ? CommandLine.arguments[$0+1] : nil })
        if let index=CommandLine.arguments.firstIndex(of:"--export-demo"),CommandLine.arguments.count>index+1 {
            AnimationExport.write(to:URL(fileURLWithPath:CommandLine.arguments[index+1]),character:renderCharacter);return
        }
        let icon = CommandLine.arguments.contains("--render-icon")
        if let index=CommandLine.arguments.firstIndex(of:icon ? "--render-icon" : "--render"),CommandLine.arguments.count>index+1 {
            // Export the bundled sprite artwork without launching a desktop pet window.
            let width = icon ? 1024 : 512, height = icon ? 1024 : 680
            guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),
                  let graphics=NSGraphicsContext(bitmapImageRep:bitmap) else { exit(1) }
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=graphics
            let context=graphics.cgContext
            context.translateBy(x:0,y:CGFloat(height));context.scaleBy(x:1,y:-1)
            if icon {
                PetRenderer.drawIcon()
            } else { PetRenderer.draw(in:CGRect(x:0,y:0,width:width,height:height),character:renderCharacter,phase:0.8,walking:true,age:1) }
            NSGraphicsContext.restoreGraphicsState()
            guard let data=bitmap.representation(using:.png,properties:[:]) else { exit(1) }
            do { try data.write(to:URL(fileURLWithPath:CommandLine.arguments[index+1])) } catch { fputs("Render failed: \(error)\n",stderr);exit(1) }
            return
        }
        let app=NSApplication.shared
        // Launch Services normally reuses the existing app. Guard direct binary launches too.
        let id="local.rafail.pickle-rick-pet"
        let running=NSRunningApplication.runningApplications(withBundleIdentifier:id).filter{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}
        if let first=running.first { first.activate();return }
        let delegate=PetController()
        app.delegate=delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
