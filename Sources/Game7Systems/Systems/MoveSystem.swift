import ECScore

struct MoveSystem {
    let mvToken: (TypeToken<PositionComponent>, TypeToken<DirectionComponent>)

    init(base: borrowing VBPF) {
        self.mvToken = interop(base, PositionComponent.self, DirectionComponent.self)
    }

    @inline(__always)
    func update(base: borrowing VBPF, dt: Duration) 
    {
        let dtSeconds = Float(dt.components.seconds) + Float(dt.components.attoseconds) / 1e18

        view(base: base, with: mvToken) 
        { _, pos, dir in

            // swift dynamic lookup has some problem when get-set simutaneously
            let dx = (dir.vx * dtSeconds) 
            let dy = (dir.vy * dtSeconds)
            pos.x += dx 
            pos.y += dy

        }
    }
}