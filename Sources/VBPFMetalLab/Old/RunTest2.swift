// import Cocoa
// import MetalKit

// // --- 1. Shader 原始碼 (字串編譯，解決你的路徑問題) ---
// fileprivate let shaderSource2 = """
// #include <metal_stdlib>
// using namespace metal;

// struct VertexOut {
//     float4 position [[position]];
//     float2 uv; // 座標範圍 -1 到 1
// };

// vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
//     // 直接定義正方形的 4 個頂點
//     float2 positions[4] = {
//         float2(-1, -1), float2(1, -1),
//         float2(-1,  1), float2(1,  1)
//     };
//     VertexOut out;
//     out.position = float4(positions[vid], 0, 1);
//     out.uv = positions[vid];
//     return out;
// }

// fragment float4 fragment_main(VertexOut in [[stage_in]]) {
//     float dist = length(in.uv); // 計算像素到中心點的距離
//     float radius = 0.5;
    
//     // 抗鋸齒平滑邊緣
//     float alpha = 1.0 - smoothstep(radius - 0.005, radius + 0.005, dist);
    
//     // 如果 dist > radius, 直接丟棄像素 (透明)
//     if (alpha <= 0.0) discard_fragment();
    
//     return float4(0.2, 0.6, 1.0, alpha); // 回傳藍色圓形
// }
// """

// class AppDelegate: NSObject, NSApplicationDelegate {
//     func applicationDidFinishLaunching(_ notification: Notification) {
//         NSApp.activate(ignoringOtherApps: true)
//     }
    
//     func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
//         return true
//     }
// }

// // --- 2. 渲染器 (Renderer) ---
// class Renderer: NSObject, MTKViewDelegate {
//     let device: MTLDevice
//     let commandQueue: MTLCommandQueue
//     let pipelineState: MTLRenderPipelineState

//     init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
//         self.device = device
//         self.commandQueue = device.makeCommandQueue()!
        
//         let library = try! device.makeLibrary(source: shaderSource2, options: nil)
//         let desc = MTLRenderPipelineDescriptor()
//         desc.vertexFunction = library.makeFunction(name: "vertex_main")
//         desc.fragmentFunction = library.makeFunction(name: "fragment_main")
//         desc.colorAttachments[0].pixelFormat = pixelFormat
        
//         // 啟用 Alpha 混合 (才能看到圓形邊緣透明)
//         desc.colorAttachments[0].isBlendingEnabled = true
//         desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//         desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
//         self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)
//     }

//     func draw(in view: MTKView) {
//         guard let buffer = commandQueue.makeCommandBuffer(),
//               let desc = view.currentRenderPassDescriptor,
//               let encoder = buffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        
//         encoder.setRenderPipelineState(pipelineState)
//         encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
//         encoder.endEncoding()
        
//         buffer.present(view.currentDrawable!)
//         buffer.commit()
//     }

//     func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
// }

// @MainActor
// func runtest2() {
//     let app = NSApplication.shared
//         app.setActivationPolicy(.regular) // 讓它成為一個真正的 UI 程式

//         let delegate = AppDelegate()
//         app.delegate = delegate
//         app.setActivationPolicy(.regular)

//         let device = MTLCreateSystemDefaultDevice()!
//         let frame = NSRect(x: 0, y: 0, width: 600, height: 600)
        
//         // 建立視窗
//         let window = NSWindow(contentRect: frame,
//                               styleMask: [.titled, .closable, .resizable],
//                               backing: .buffered, defer: false)
//         window.title = "VBPF Metal 實驗室 - 圓形渲染"
//         window.center()
//         window.makeKeyAndOrderFront(nil)

//         // 建立 MTKView
//         let mtkView = MTKView(frame: frame, device: device)
//         mtkView.colorPixelFormat = .bgra8Unorm
//         mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
//         let renderer = Renderer(device: device, pixelFormat: mtkView.colorPixelFormat)
//         mtkView.delegate = renderer
        
//         window.contentView = mtkView
        
//         NSApp.activate(ignoringOtherApps: true)
//         app.run() // 啟動事件循環
// }
