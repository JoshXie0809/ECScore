import Cocoa
import MetalKit

@MainActor
func runTest4() {
    if Bundle.main.bundleIdentifier == nil {
        UserDefaults.standard.set("josh.ECScoreMetalLab", forKey: "CFBundleIdentifier")
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)

    let device = MTLCreateSystemDefaultDevice()!
    let frame = NSRect(x: 0, y: 0, width: 600, height: 600)
    let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "ECScore Engine Skeleton"
    window.makeKeyAndOrderFront(nil)

    let mtkView = MTKView(frame: frame, device: device)
    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
    mtkView.preferredFramesPerSecond = 60

    let world = GameWorld()
    let renderer = Renderer(device: device, pixelFormat: mtkView.colorPixelFormat, capacity: GameWorld.totalParticles)
    let loop = GameLoop(world: world, renderer: renderer, capacity: GameWorld.totalParticles)

    mtkView.delegate = loop
    window.contentView = mtkView

    app.run()
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
