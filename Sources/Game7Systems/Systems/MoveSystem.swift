import ECScore

public struct MoveSystem {
    let mvToken: (TypeToken<PositionComponent>, TypeToken<DirectionComponent>)

    init(base: borrowing VBPF) {
        self.mvToken = interop(base, PositionComponent.self, DirectionComponent.self)
    }

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
        //     // swift dynamic lookup sometimes has problem when get-set simutaneously
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

    public struct MoveLogic: SystemBody {
        public let dtSeconds: Float

        public typealias Components = (ComponentProxy<PositionComponent>, ComponentProxy<DirectionComponent>)
        @inlinable 
        @inline(__always)
        public func execute(taskId: Int, components: Components) {
            let (pos, dir) = components
            pos.x += (dir.vx * dtSeconds)
            pos.y += (dir.vy * dtSeconds)
        }
    }
}
