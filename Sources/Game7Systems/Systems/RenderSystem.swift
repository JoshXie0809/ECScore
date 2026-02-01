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
        let buffer = world.frameBuffer
        
        view(base: world.base, with: renderToken) 
        { _, pos, sprite in
            
            let x = Int(pos.x)
            let y = Int(pos.y)
            let char = sprite.character
            buffer.draw(x: x, y: y, char: char)
            
        }

        _fixLifetime(buffer)
    }
}