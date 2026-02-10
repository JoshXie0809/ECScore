import ECScore

struct DataSystem {
    let dataToken: TypeToken<DataComponent>

    init(base: borrowing VBPF) {
        self.dataToken = interop(base, DataComponent.self)
    }

    @inlinable
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
    
    struct DataLogic: SystemBody {
        let dtSeconds: Double

        typealias Components = ComponentProxy<DataComponent>
        @inlinable 
        @inline(__always)
        func execute(taskId: Int, components: Components) {
        
            let _data = components
            // get fast proxy
            let data_fast = _data.fast

            data_fast.thingy = (data_fast.thingy + 1) % 1_000_000
            data_fast.dingy += 0.0001 * dtSeconds
            data_fast.mingy = !data_fast.mingy
            data_fast.numgy = data_fast.rng.next()

        }
    }
}