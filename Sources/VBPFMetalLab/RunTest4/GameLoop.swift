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
        // update resource
        let now = CACurrentMediaTime()
        world.dt = Float(now - lastTime)
        lastTime = now
        world.mainCharDir = InputManager.shared.moveVector
        world.updateParticelColor()

        // update entity
        world.updateParticles()
        world.updateMainCharacter()

        // extract data
        let pPtr = renderer.writableInstancePtr(capacity: capacity)
        let cPtr = renderer.writableColorPtr(capacity: capacity)
        let count = world.extractDataParticles(posPtr: pPtr, colPtr: cPtr, capacity: capacity)

        let mainCharPtr = renderer.writableMainCharacterPtr()
        let _ = world.extractDataMainCharacter(mainCharPtr: mainCharPtr)

        let trailPtr = renderer.writableTrailPtr() // 你需要在 Renderer 增加這個方法
        world.extractHeroTrail(trailPtr: trailPtr)

        renderer.submit(mtk_view: mtk_view, instanceCount: count, time: Float(now))
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
}
