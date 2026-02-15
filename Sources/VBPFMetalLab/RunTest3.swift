import Cocoa
import MetalKit
import ECScore

// --- 1. 組件定義 (來自 Test 3) ---
struct MainChar: TagComponent {}

@FastProxy
struct Position: Component {
    var x: Double = 0.0
    var y: Double = 0.0
}

@FastProxy
struct Velocity: Component {
    var dx: Double = 0.0
    var dy: Double = 0.0
}

// --- 2. Shader 修正：加入位置偏移 ---
// --- 2. Shader 修正：縮小尺寸並優化 UV ---
fileprivate let shaderSourceInstanced = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(uint vid [[vertex_id]], 
                             uint iid [[instance_id]], 
                             constant float2 *allPos [[buffer(0)]]) {

    float size = 0.025; 
    float2 quad[4] = { 
        float2(-size, -size), float2(size, -size), 
        float2(-size,  size), float2(size,  size) 
    };
    
    VertexOut out;
    float2 pos = allPos[iid]; 
    out.position = float4(quad[vid] + pos, 0, 1);
    
    // 這樣在 fragment shader 算出的 length(uv) 在邊緣剛好會是 1.0
    out.uv = quad[vid] * (1.0 / size); 
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    float dist = length(in.uv);
    // 抗鋸齒半徑維持在 0.5 左右即可
    float alpha = 1.0 - smoothstep(0.45, 0.5, dist);
    if (alpha <= 0.0) discard_fragment();
    return float4(0.4, 0.7, 1.0, alpha); 
}
"""

// --- 3. 渲染器：注入 ECScore ---
final class ECSRenderer: NSObject, MTKViewDelegate {
    // 挑戰 10,000 顆球，看看優化後的 CPU 佔用率
    static let total = 1_000
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let base = makeBootedPlatform()
    
    let pToken: TypeToken<Position>
    let vToken: TypeToken<Velocity>
    
    // 【核心優化】：預分配一個持久的 GPU 緩衝區
    let gpuPositionBuffer: MTLBuffer

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.pToken = interop(base, Position.self)
        self.vToken = interop(base, Velocity.self)

        // 1. 初始化 GPU 緩衝區 (Shared 模式讓 CPU/GPU 共享同一塊記憶體)
        let bufferSize = MemoryLayout<simd_float2>.stride * Self.total
        self.gpuPositionBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)!

        // 2. 建立管線
        let library = try! device.makeLibrary(source: shaderSourceInstanced, options: nil)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "vertex_main")
        desc.fragmentFunction = library.makeFunction(name: "fragment_main")
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)

        // 3. 初始化 10,000 個實體
        let mcT = (self.pToken, self.vToken)
        emplace(base, tokens: mcT) { entities, pack in
            var (pST, vST) = pack.storages
            for _ in 0..<Self.total {
                let e = entities.createEntity()
                pST.addComponent(e, Position(x: .random(in: -1...1), y: .random(in: -1...1)))
                vST.addComponent(e, Velocity(dx: .random(in: -0.005...0.005), dy: .random(in: -0.005...0.005)))
            }
        }
    }

    func draw(in mtkView: MTKView) {
        // --- 1. 邏輯更新與數據提取 (同步進行) ---
        // 獲取 GPU 緩衝區的原始指針
        let ptr = gpuPositionBuffer.contents().bindMemory(to: simd_float2.self, capacity: Self.total)
        var idx = 0

        // 這裡我們只跑一次 view，同時完成「物理更新」與「數據同步」
        view(base: base, with: (pToken, vToken)) { _, pos, vel in
            let p = pos.fast; let v = vel.fast
            
            // 物理運算
            p.x += v.dx; p.y += v.dy
            if p.x > 1.0 || p.x < -1.0 { v.dx *= -1 }
            if p.y > 1.0 || p.y < -1.0 { v.dy *= -1 }
            
            // 【零拷貝】：直接寫入 GPU 記憶體地址，不經過 Array，不經過 append
            ptr[idx] = simd_float2(Float(p.x), Float(p.y))
            idx += 1
        }

        // --- 2. 渲染 ---
        guard let buffer = commandQueue.makeCommandBuffer(),
              let desc = mtkView.currentRenderPassDescriptor,
              let encoder = buffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // 直接告訴 GPU 去我們剛才寫入的那個緩衝區拿數據
        encoder.setVertexBuffer(gpuPositionBuffer, offset: 0, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, 
                               vertexStart: 0, 
                               vertexCount: 4, 
                               instanceCount: idx)
        
        encoder.endEncoding()
        buffer.present(mtkView.currentDrawable!)
        buffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

@MainActor
func runCombinedTest() {

    if Bundle.main.bundleIdentifier == nil {
        UserDefaults.standard.set("josh.ECScoreMetalLab", forKey: "CFBundleIdentifier")
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    
    let device = MTLCreateSystemDefaultDevice()!
    let frame = NSRect(x: 0, y: 0, width: 800, height: 800)
    let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "ECScore + Metal 實時邏輯渲染"
    window.makeKeyAndOrderFront(nil)

    let mtkView = MTKView(frame: frame, device: device)
    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
    
    // 使用我們結合後的 Renderer
    let renderer = ECSRenderer(device: device, pixelFormat: mtkView.colorPixelFormat)
    mtkView.delegate = renderer
    
    window.contentView = mtkView
    app.run()
}
