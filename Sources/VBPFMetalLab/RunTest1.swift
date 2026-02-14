import Metal

let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct AddParams { uint count; };

    kernel void add_arrays(
        const device float* inA [[buffer(0)]],
        const device float* inB [[buffer(1)]],
        device float* outC [[buffer(2)]],
        constant AddParams& params [[buffer(3)]],
        uint gid [[thread_position_in_grid]]
    ) {
        if (gid >= params.count) { return; }
        outC[gid] = inA[gid] + inB[gid];
    }
    """

struct AddParams {
    var count: UInt32
}

func runtest1() {
    guard let device = MTLCreateSystemDefaultDevice() else { return }
    guard let queue = device.makeCommandQueue() else { return }
    guard let library = try? device.makeLibrary(source: shaderSource, options: nil) else {
        print("❌ Shader 語法錯誤！")
        return
    }

    guard let function = library.makeFunction(name: "add_arrays") else { return }
    let pipelineState = try! device.makeComputePipelineState(function: function)

    // 資料準備
    let a: [Float] = [1, 2, 3, 4, 5, 6, 7, 8]
    let b: [Float] = [10, 20, 30, 40, 50, 60, 70, 888880]
    let byteCount = a.count * MemoryLayout<Float>.stride

    let aBuffer = device.makeBuffer(bytes: a, length: byteCount, options: .storageModeShared)!
    let bBuffer = device.makeBuffer(bytes: b, length: byteCount, options: .storageModeShared)!
    let outBuffer = device.makeBuffer(length: byteCount, options: .storageModeShared)!

    var params = AddParams(count: UInt32(a.count))

    // 執行
    let commandBuffer = queue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(pipelineState)
    encoder.setBuffer(aBuffer, offset: 0, index: 0)
    encoder.setBuffer(bBuffer, offset: 0, index: 1)
    encoder.setBuffer(outBuffer, offset: 0, index: 2)
    encoder.setBytes(&params, length: MemoryLayout<AddParams>.stride, index: 3)

    encoder.dispatchThreads(MTLSize(width: a.count, height: 1, depth: 1), 
                            threadsPerThreadgroup: MTLSize(width: min(a.count, 32), height: 1, depth: 1))
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let out = outBuffer.contents().bindMemory(to: Float.self, capacity: a.count)
    print("✅ GPU 計算結果:", Array(UnsafeBufferPointer(start: out, count: a.count)))

}