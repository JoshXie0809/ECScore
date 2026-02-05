import ECScore

struct MoveSystem {
    let mvToken: (TypeToken<PositionComponent>, TypeToken<DirectionComponent>)

    init(base: borrowing VBPF) {
        self.mvToken = interop(base, PositionComponent.self, DirectionComponent.self)
    }

    @inline(__always)
    func update(_ world: borrowing World)
    {
        let dt = world.dt
        let dtSeconds = Float(dt.components.seconds) + Float(dt.components.attoseconds) / 1e18

        view(base: world.base, with: mvToken) 
        { _, pos, dir in
            // swift dynamic lookup sometimes has problem when get-set simutaneously
            // case
            pos.x += (dir.vx * dtSeconds) // get and set 
            pos.y += (dir.vy * dtSeconds)

            // // so if compiler have problem 
            // // try this
            // let nx = (dir.vx * dtSeconds) + pos.x // only get
            // let ny = (dir.vy * dtSeconds) + pos.y
            // pos.x = nx
            // pos.y = ny
        }

    }
}
