import ECScore

public struct DataSystem {
    let dataToken: TypeToken<DataComponent>

    init(base: borrowing VBPF) {
        self.dataToken = interop(base, DataComponent.self)
    }

    @inline(__always)
    func update(_ world: borrowing World)
    {
        let dt = world.dt
        let dtSeconds = Double(dt.components.seconds) + Double(dt.components.attoseconds) / 1e18
        let logic = Self.DataLogic(dtSeconds: dtSeconds)
        view(base: world.base, with: dataToken, logic) 

        // view(base: world.base, with: dataToken) 
        // { _, data in
        //     data.thingy = (data.thingy + 1) % 1_000_000
        //     data.dingy += 0.0001 * dtSeconds
        //     data.mingy = !data.mingy
        //     data.numgy = data.rng.next()
        // }
    }

    public struct DataLogic: SystemBody {
        public  let dtSeconds: Double

        public typealias Components = ComponentProxy<DataComponent>
        @inlinable 
        @inline(__always)
        public func execute(taskId: Int, components: Components) {

            let data = components
            data.thingy = (data.thingy + 1) % 1_000_000
            data.dingy += 0.0001 * dtSeconds
            data.mingy = !data.mingy
            data.numgy = data.rng.next()

        }
    }
}