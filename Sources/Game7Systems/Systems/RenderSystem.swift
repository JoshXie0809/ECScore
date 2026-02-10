import ECScore

struct RenderSystem {
    // 定義所需組件的 Token
    let renderToken: (TypeToken<PositionComponent>, TypeToken<SpriteComponent>)
    // let withTagToken: TypeToken<EmptyComponent>

    init(base: borrowing VBPF) {
        // 預先取得組件位置，確保效能
        self.renderToken = interop(base, PositionComponent.self, SpriteComponent.self)
    }

    @inlinable
    @inline(__always)
    func update(_ world: borrowing World) {
        let buffer = world.frameBuffer.getBufferPtr()
        let height = world.frameBuffer.height
        let width = world.frameBuffer.width

        let logic = Self.RenderLogic(buffer: buffer, height: height, width: width)
        // view(base: world.base, with: renderToken, withTag: withTagToken, logic)
        view(base: world.base, with: renderToken, logic)

        _fixLifetime(buffer)
    }

    struct RenderLogic: SystemBody {
        let buffer: UnsafeMutablePointer<UInt8>
        let height: Int
        let width: Int

        typealias Components = (ComponentProxy<PositionComponent>, ComponentProxy<SpriteComponent>)

        @inlinable 
        @inline(__always)
        func execute(taskId: Int, components: Components) {
            let (_pos, _sprite) = components
            // get fast proxy
            let (pos_fast, sprite_fast) = (_pos.fast, _sprite.self)
            
            let x = Int(pos_fast.x)
            let y = Int(pos_fast.y)
            let char = sprite_fast.character

            if y >= 0 && y < height && x >= 0 && x < width {
                buffer[x + y * width] = char
            }
        }
    }
}


