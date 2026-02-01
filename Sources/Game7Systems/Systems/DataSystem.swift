import ECScore

struct DataSystem {
    let dataToken: TypeToken<DataComponent>

    init(base: borrowing VBPF) {
        self.dataToken = interop(base, DataComponent.self)
    }

    @inline(__always)
    func update(base: borrowing VBPF, dt: Duration) 
    {
        let dtSeconds = Double(dt.components.seconds) + Double(dt.components.attoseconds) / 1e18

        view(base: base, with: dataToken) 
        { _, data in

            data.thingy = (data.thingy + 1) % 1_000_000
            data.dingy += 0.0001 * dtSeconds
            data.mingy = !data.mingy
            data.numgy = data.rng.next()
            
        }
    }
}