import Foundation
import Metal

struct AddParams {
    var count: UInt32
}

@main
struct VBPFMetalLab {
    static func main() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not available on this machine.")
            return
        }
        guard let queue = device.makeCommandQueue() else {
            print("Failed to create command queue.")
            return
        }

        let library: MTLLibrary
        if let lib = try? device.makeDefaultLibrary(bundle: .main) {
            library = lib
        } else if let lib = device.makeDefaultLibrary() {
            library = lib
        } else {
            print("Failed to load Metal library.")
            return
        }

        guard let function = library.makeFunction(name: "add_arrays") else {
            print("Failed to load function add_arrays.")
            return
        }
        let pipelineState: MTLComputePipelineState
        do {
            pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create compute pipeline: \(error)")
            return
        }

        let a: [Float] = [1, 2, 3, 4, 5, 6, 7, 8]
        let b: [Float] = [10, 20, 30, 40, 50, 60, 70, 80]
        precondition(a.count == b.count)

        let byteCount = a.count * MemoryLayout<Float>.stride
        guard let aBuffer = device.makeBuffer(bytes: a, length: byteCount),
              let bBuffer = device.makeBuffer(bytes: b, length: byteCount),
              let outBuffer = device.makeBuffer(length: byteCount)
        else {
            print("Failed to create buffers.")
            return
        }

        var params = AddParams(count: UInt32(a.count))
        guard let paramsBuffer = device.makeBuffer(
            bytes: &params,
            length: MemoryLayout<AddParams>.stride
        ) else {
            print("Failed to create params buffer.")
            return
        }

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            print("Failed to create command buffer or encoder.")
            return
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(aBuffer, offset: 0, index: 0)
        encoder.setBuffer(bBuffer, offset: 0, index: 1)
        encoder.setBuffer(outBuffer, offset: 0, index: 2)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 3)

        let width = pipelineState.threadExecutionWidth
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let threadsPerGrid = MTLSize(width: a.count, height: 1, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let out = outBuffer.contents().bindMemory(to: Float.self, capacity: a.count)
        let result = Array(UnsafeBufferPointer(start: out, count: a.count))

        print("A:", a)
        print("B:", b)
        print("A + B (GPU):", result)
    }
}
