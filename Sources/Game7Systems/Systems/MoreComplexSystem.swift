import ECScore

typealias DirectionComponent = VelocityComponent
struct MoreComplexSystem {
    let mcToken: (TypeToken<PositionComponent>, TypeToken<DirectionComponent>, TypeToken<DataComponent>)

    init(base: borrowing VBPF) {
        self.mcToken = interop(base, PositionComponent.self, DirectionComponent.self, DataComponent.self)
    }

    @inline(__always)
    func update(_ world: borrowing World)
    {
        view(base: world.base, with: mcToken) 
        { _, pos, dir, data in

            if (data.thingy % 10) == 0 {
                if pos.x > pos.y {
                    dir.vx = Float(data.rng.range(3, 19)) - 10.0
                    dir.vy = Float(data.rng.range(0, 5))
                }
                else {
                    dir.vx = Float(data.rng.range(0, 5))
                    dir.vy = Float(data.rng.range(3, 19)) - 10.0
                }
            }

        }
    }
}