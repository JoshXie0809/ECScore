import Cocoa
import MetalKit
import ECScore

// --- 1. 組件定義 ---
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

// 注意：我們不需要每個實體都存 ColorComponent 了，
// 因為我們改用 ID 查表法，這樣更節省內存且速度更快。

// --- 2. Shader 原始碼 ---
fileprivate let shaderSourceWithColor = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float2 uv;
};

vertex VertexOut vertex_main(uint vid [[vertex_id]], 
                             uint iid [[instance_id]], 
                             constant float2 *allPos [[buffer(0)]],
                             constant float3 *allColors [[buffer(1)]]) {
    float size = 0.015;
    float2 quad[4] = { float2(-size, -size), float2(size, -size), 
                       float2(-size,  size), float2(size,  size) };
    
    VertexOut out;
    out.position = float4(quad[vid] + allPos[iid], 0, 1);
    out.color = allColors[iid];
    out.uv = quad[vid] * (1.0 / size); 
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    float dist = length(in.uv);
    float alpha = 1.0 - smoothstep(0.45, 0.5, dist);
    if (alpha <= 0.0) discard_fragment();
    return float4(in.color, alpha); 
}
"""

// --- 3. 渲染器 (ECSRenderer) ---
final class ECSRenderer: NSObject, MTKViewDelegate {
    static let total = 10_000
    static let tableSize = 256    // 預製顏色表大小
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let base = makeBootedPlatform()
    
    let pToken: TypeToken<Position>
    let vToken: TypeToken<Velocity>

    let gpuPositionBuffer: MTLBuffer
    let gpuColorBuffer: MTLBuffer
    
    // 【核心優化】：準備 128 個顏色向量
    var colorTable: [simd_float3] = (0..<tableSize).map { _ in
        simd_float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
    }

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.pToken = interop(base, Position.self)
        self.vToken = interop(base, Velocity.self)

        // 1. 初始化 GPU 緩衝區
        let posSize = MemoryLayout<simd_float2>.stride * Self.total
        let colorSize = MemoryLayout<simd_float3>.stride * Self.total
        self.gpuPositionBuffer = device.makeBuffer(length: posSize, options: .storageModeShared)!
        self.gpuColorBuffer = device.makeBuffer(length: colorSize, options: .storageModeShared)!

        // 2. 編譯 Shader
        let library = try! device.makeLibrary(source: shaderSourceWithColor, options: nil)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "vertex_main")
        desc.fragmentFunction = library.makeFunction(name: "fragment_main")
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)

        // 3. 初始化實體 (不再需要加入 ColorComponent，直接查表)
        emplace(base, tokens: (pToken, vToken)) { entities, pack in
            var (pST, vST) = pack.storages
            for _ in 0..<Self.total {
                let e = entities.createEntity()
                pST.addComponent(e, Position(x: .random(in: -1...1), y: .random(in: -1...1)))
                vST.addComponent(e, Velocity(dx: .random(in: -0.003...0.003), dy: .random(in: -0.003...0.003)))
            }
        }
    }

    func draw(in mtkView: MTKView) {
        for i in 0..<Self.tableSize {
            let offset = Float.random(in: -0.01...0.01)
            colorTable[i].x = max(0, min(1, colorTable[i].x + offset))
            colorTable[i].y = max(0, min(1, colorTable[i].y + Float.random(in: -0.01...0.01)))
            colorTable[i].z = max(0, min(1, colorTable[i].z + Float.random(in: -0.01...0.01)))
        }

        // --- 階段 B：ECScore 邏輯更新與數據同步 ---
        let posPtr = gpuPositionBuffer.contents().bindMemory(to: simd_float2.self, capacity: Self.total)
        let colPtr = gpuColorBuffer.contents().bindMemory(to: simd_float3.self, capacity: Self.total)
        var idx = 0

        // 零拷貝遍歷：物理計算 + 顏色查表
        view(base: base, with: (pToken, vToken)) { iterId, pos, vel in
            let p = pos.fast
            let v = vel.fast
            
            p.x += v.dx
            p.y += v.dy
            
            if p.x > 1.0 || p.x < -1.0 { v.dx *= -1 }
            if p.y > 1.0 || p.y < -1.0 { v.dy *= -1 }
            
            let ax = Float(p.x)
            let ay = Float(p.y)
            
            posPtr[idx] = simd_float2(ax, ay)
            colPtr[idx] = colorTable[Int(iterId.eidId & 127)]
            
            idx += 1
        }

        // --- 階段 C：Metal 渲染 ---
        guard let buffer = commandQueue.makeCommandBuffer(),
              let desc = mtkView.currentRenderPassDescriptor,
              let encoder = buffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(gpuPositionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(gpuColorBuffer, offset: 0, index: 1)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: idx)
        
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
    window.title = "ECScore (LUT 優化版)"
    window.center()
    window.makeKeyAndOrderFront(nil)

    let mtkView = MTKView(frame: frame, device: device)
    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0)
    
    let renderer = ECSRenderer(device: device, pixelFormat: mtkView.colorPixelFormat)
    mtkView.delegate = renderer
    
    window.contentView = mtkView
    app.run()
}
