import SwiftUI

@main
struct VBPFInspectorApp: App {
    // 連結獨立的 Delegate
    @NSApplicationDelegateAdaptor(InspectorDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            InspectorHomeView() // 呼叫獨立的 View
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 600)
    }
}


