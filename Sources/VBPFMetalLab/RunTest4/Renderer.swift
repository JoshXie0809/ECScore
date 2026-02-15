import MetalKit
import simd

@MainActor
final class Renderer {
    static let maxFramesInFlight = 3
    
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    
    // Ring Buffer
    // max 3
    private let instanceBuffers: [MTLBuffer]
    private let colorBuffers: [MTLBuffer]
    private var currentFrameIndex = 0
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxFramesInFlight)

    init(device: MTLDevice, pixelFormat: MTLPixelFormat, capacity: Int) {
        self.device = device
        self.queue = device.makeCommandQueue()!

        let posBytes = MemoryLayout<simd_float2>.stride * capacity
        let colorBytes = MemoryLayout<simd_float3>.stride * capacity
        
        self.instanceBuffers = (0..<Self.maxFramesInFlight).map { _ in
            device.makeBuffer(length: posBytes, options: .storageModeShared)!
        }
        
        self.colorBuffers = (0..<Self.maxFramesInFlight).map { _ in
            device.makeBuffer(length: colorBytes, options: .storageModeShared)!
        }
        
        let library = try! device.makeLibrary(
            URL: Bundle.module.url(forResource: "default", withExtension: "metallib")!
        )

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "vertex_main")
        desc.fragmentFunction = library.makeFunction(name: "fragment_main")
        
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.pipeline = try! device.makeRenderPipelineState(descriptor: desc)
    }
    
    func writableColorPtr(capacity: Int) -> UnsafeMutablePointer<simd_float3> {
            colorBuffers[currentFrameIndex].contents().bindMemory(to: simd_float3.self, capacity: capacity)
    }

    func writableInstancePtr(capacity: Int) -> UnsafeMutablePointer<simd_float2> {
        instanceBuffers[currentFrameIndex].contents().bindMemory(to: simd_float2.self, capacity: capacity)
    }

    func submit(mtk_view: MTKView, instanceCount: Int) {
        // 1. 等待一個可用的 Buffer (消耗一個訊號)
        _ = inFlightSemaphore.wait(timeout: .distantFuture)

        guard instanceCount > 0,
              let cmd = queue.makeCommandBuffer(),
              let rp = mtk_view.currentRenderPassDescriptor,
              let enc = cmd.makeRenderCommandEncoder(descriptor: rp),
              let drawable = mtk_view.currentDrawable else {
                  // 重要：如果這裡 return 了，一定要補回一個訊號，否則會永久卡死
                  inFlightSemaphore.signal()
                  return
              }

        enc.setRenderPipelineState(pipeline)
        enc.setVertexBuffer(instanceBuffers[currentFrameIndex], offset: 0, index: 0)
        enc.setVertexBuffer(colorBuffers[currentFrameIndex], offset: 0, index: 1)
        
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instanceCount)
        enc.endEncoding()

        // --- 【關鍵修正點：回傳訊號】 ---
        // 當 GPU 真正執行完這條指令後，會進入這個閉包，這時才釋放訊號讓 CPU 寫入下一幀
        cmd.addCompletedHandler { [weak self] _ in
            self?.inFlightSemaphore.signal()
        }

        cmd.present(drawable)
        cmd.commit()
        
        // 更新索引，準備給下一幀的 writablePtr 使用
        // 循環公式：$currentFrameIndex = (currentFrameIndex + 1) \pmod{3}$
        currentFrameIndex = (currentFrameIndex + 1) % Self.maxFramesInFlight
    }
}
