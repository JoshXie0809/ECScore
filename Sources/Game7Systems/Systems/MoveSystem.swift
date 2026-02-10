import ECScore

struct MoveSystem {
    let mvToken: (TypeToken<PositionComponent>, TypeToken<DirectionComponent>)

    init(base: borrowing VBPF) {
        self.mvToken = interop(base, PositionComponent.self, DirectionComponent.self)
    }

    @inlinable
    @inline(__always)
    func update(_ world: borrowing World)
    {
        let dt = world.dt
        let dtSeconds = Float(dt.components.seconds) + Float(dt.components.attoseconds) / 1e18
        let logic = Self.MoveLogic(dtSeconds: dtSeconds)
        view(base: world.base, with: mvToken, logic) 

        // slow path, so I use static stuct

        // view(base: world.base, with: mvToken) 
        // { _, pos, dir in
        //     // swift dynamic lookup sometimes has more cost when get-set simutaneously
        //     // case
        //     pos.x += (dir.vx * dtSeconds) // get and set 
        //     pos.y += (dir.vy * dtSeconds)

        //     // // so if compiler have problem 
        //     // // try this
        //     // let nx = (dir.vx * dtSeconds) + pos.x // only get
        //     // let ny = (dir.vy * dtSeconds) + pos.y
        //     // pos.x = nx // only set
        //     // pos.y = ny
        // }

    }

    struct MoveLogic: SystemBody {
        let dtSeconds: Float

        typealias Components = (ComponentProxy<PositionComponent>, ComponentProxy<DirectionComponent>)
        @inlinable 
        @inline(__always)
        func execute(taskId: Int, components: Components) {
            let (_pos, _dir) = components
            // get fast proxy
            let (pos_fast, dir_fast) = (_pos.fast, _dir.fast)

            // default path

            // let vx = dir.vx
            // let vy = dir.vy
            // let dx = vx * dtSeconds
            // let dy = vy * dtSeconds
            // pos.x += dx
            // pos.y += dy

            let vx = dir_fast.vx
            let vy = dir_fast.vy
            let dx = vx * dtSeconds
            let dy = vy * dtSeconds
            pos_fast.x += dx
            pos_fast.y += dy
        }
    }
}
