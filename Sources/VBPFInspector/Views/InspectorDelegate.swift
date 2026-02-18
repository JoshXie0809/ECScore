import AppKit
import ECScore


@MainActor
@Observable
final class InspectorDelegate: NSObject, NSApplicationDelegate {
    let world = GameWorld()
    var refreshTrigger: Int = 0
    func tick() { refreshTrigger += 1 }
    
    static private(set) var shared: InspectorDelegate?

    override init() {
        super.init()
        InspectorDelegate.shared = self
        if Bundle.main.bundleIdentifier == nil {
            UserDefaults.standard.set("josh.ECScoreMetalLab", forKey: "CFBundleIdentifier")
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {

        NSWindow.allowsAutomaticWindowTabbing = false
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        // #######################################################
        // 這裡以後要轉移， 先測試
        // 嘗試加入 Resource

        guard let shared = InspectorDelegate.shared else {
            fatalError("cannot get shared @InspectorDelegate")
        }

        let hwToken = interop(shared.world.resources, HelloWorld.self)

        emplace(shared.world.resources, tokens: hwToken) {
            entities, pack in
            var hw = pack.storages

            let e = entities.createEntity()
            hw.addComponent(e, HelloWorld(specialId: "josh", val: "hello_world"))
        }

        // components
        let _ = interop(shared.world.base, Num1.self, Num2.self)
        
        tick()
        // #######################################################
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
