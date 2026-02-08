import ECScore

public struct RenderSystem {
    // 定義所需組件的 Token
    let renderToken: (TypeToken<PositionComponent>, TypeToken<SpriteComponent>)
    // let withTagToken: TypeToken<EmptyComponent>

    init(base: borrowing VBPF) {
        // 預先取得組件位置，確保效能
        self.renderToken = interop(base, PositionComponent.self, SpriteComponent.self)
    }

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

    public struct RenderLogic: SystemBody {
        public let buffer: UnsafeMutablePointer<UInt8>
        public let height: Int
        public let width: Int

        public typealias Components = (ComponentProxy<PositionComponent>, ComponentProxy<SpriteComponent>)

        @inlinable 
        @inline(__always)
        public func execute(taskId: Int, components: Components) {
            let (pos, sprite) = components
            let x = Int(pos.x)
            let y = Int(pos.y)
            let char = sprite.character

            if y >= 0 && y < height && x >= 0 && x < width {
                buffer[x + y * width] = char
            }
        }
    }
}


