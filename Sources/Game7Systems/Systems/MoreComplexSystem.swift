import ECScore

typealias DirectionComponent = VelocityComponent
struct MoreComplexSystem {
    let mcToken: (TypeToken<PositionComponent>, TypeToken<DirectionComponent>, TypeToken<DataComponent>)

    init(base: borrowing VBPF) {
        self.mcToken = interop(base, PositionComponent.self, DirectionComponent.self, DataComponent.self)
    }

    @inlinable
    @inline(__always)
    func update(_ world: borrowing World)
    {
        let logic = Self.MCLogic()
        view(base: world.base, with: mcToken, logic)

        // closuer is a little bit slow so I use static struct path for bench
        // view(base: world.base, with: mcToken) 
        // { _, pos, dir, data in
        //     if (data.thingy % 10) == 0 {
        //         if pos.x > pos.y {
        //             dir.vx = Float(data.rng.range(3, 19)) - 10.0
        //             dir.vy = Float(data.rng.range(0, 5))
        //         }
        //         else {
        //             dir.vx = Float(data.rng.range(0, 5))
        //             dir.vy = Float(data.rng.range(3, 19)) - 10.0
        //         }
        //     }
        // }
    }

    struct MCLogic: SystemBody {
        typealias Components = (ComponentProxy<PositionComponent>, ComponentProxy<DirectionComponent>, ComponentProxy<DataComponent>)
        
        @inlinable 
        @inline(__always)
        func execute(taskId: Int, components: Components) {
            let (_pos, _dir, _data) = components
            // get fast proxy 
            let (pos_fast, dir_fast, data_fast) = (_pos.fast, _dir.fast, _data.fast)

            if (data_fast.thingy % 10) == 0 {
                if pos_fast.x > pos_fast.y {
                    dir_fast.vx = Float(data_fast.rng.range(3, 19)) - 10.0
                    dir_fast.vy = Float(data_fast.rng.range(0, 5))
                }
                else {
                    dir_fast.vx = Float(data_fast.rng.range(0, 5))
                    dir_fast.vy = Float(data_fast.rng.range(3, 19)) - 10.0
                }
            }
        }
    }
}