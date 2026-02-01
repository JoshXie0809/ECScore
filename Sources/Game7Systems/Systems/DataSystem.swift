import ECScore

struct DataSystem {
    let dataToken: TypeToken<DataComponent>

    init(base: borrowing VBPF) {
        self.dataToken = interop(base, DataComponent.self)
    }

    @inline(__always)
    func update(_ world: borrowing World)
    {
        let dt = world.dt
        let dtSeconds = Double(dt.components.seconds) + Double(dt.components.attoseconds) / 1e18
        
        view(base: world.base, with: dataToken) 
        { _, data in

            data.thingy = (data.thingy + 1) % 1_000_000
            data.dingy += 0.0001 * dtSeconds
            data.mingy = !data.mingy
            data.numgy = data.rng.next()
            
        }
    }
}