import MetalKit

final class GameLoop: NSObject, MTKViewDelegate {
    let world: GameWorld
    let renderer: Renderer
    let capacity: Int
    var lastTime: CFTimeInterval = CACurrentMediaTime()

    init(world: GameWorld, renderer: Renderer, capacity: Int) {
        self.world = world
        self.renderer = renderer
        self.capacity = capacity
    }

    func draw(in mtk_view: MTKView) {
        let now = CACurrentMediaTime()
        let dt = now - lastTime
        lastTime = now

        world.update(dt: Float(dt))

        let pPtr = renderer.writableInstancePtr(capacity: capacity)
        let cPtr = renderer.writableColorPtr(capacity: capacity)
        let count = world.extractData(posPtr: pPtr, colPtr: cPtr, capacity: capacity)

        renderer.submit(mtk_view: mtk_view, instanceCount: count)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
}
