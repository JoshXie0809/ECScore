import SwiftUI

@main
struct VBPFInspectorApp: App {
    // 連結獨立的 Delegate
    @NSApplicationDelegateAdaptor(InspectorDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        Window("VBPF Inspector View", id: "inspector_window") {
            InspectorHomeView()
                .onAppear {
                    // 當此視窗出現時，自動打開遊戲視窗
                    openWindow(id: "game_window")
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 600)

        Window("VBPF Game View", id: "game_window") {
            InspectorHomeView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 400, height: 300)
    }
}


