import ECScore

struct RenderSystem {
    // 定義所需組件的 Token
    let renderToken: (TypeToken<PositionComponent>, TypeToken<SpriteComponent>)

    init(base: borrowing VBPF) {
        // 預先取得組件位置，確保效能
        self.renderToken = interop(base, PositionComponent.self, SpriteComponent.self)
    }

    @inline(__always)
    func update(_ world: borrowing World) {
        let buffer = world.frameBuffer.getBufferPtr()
        let height = world.frameBuffer.height
        let width = world.frameBuffer.width

        let logic = RenderLogic(buffer: buffer, height: height, width: width)
        view(base: world.base, with: renderToken, logic)

        _fixLifetime(buffer)
    }
}

struct RenderLogic: SystemBody {
    let buffer: UnsafeMutablePointer<UInt8>
    let height: Int
    let width: Int

    public typealias Components = (ComponentProxy<PositionComponent>, ComponentProxy<SpriteComponent>)
    @inlinable 
    @inline(__always)
    func execute(taskId: Int, components: Components) {
        let (pos, sprite) = components
        let x = Int(pos.x)
        let y = Int(pos.y)
        let char = sprite.character

        if y >= 0 && y < height && x >= 0 && x < width {
            buffer[x + y * width] = char
        }
    }
}
