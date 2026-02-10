import ECScore

struct HealthSystem {
    let hToken: TypeToken<HealthComponent>

    init(base: borrowing VBPF) {
        self.hToken = interop(base, HealthComponent.self)
    }

    @inlinable
    @inline(__always)
    func update(_ world: borrowing World)
    {
        let logic = Self.HealtLogic()
        view(base: world.base, with: hToken, logic) 


        // view(base: world.base, with: hToken) 
        // { _, health in
        //     if(health.hp <= 0 && health.status != .dead) {
        //         health.hp = 0
        //         health.status = .dead
        //     }
        //     else if(health.status == .dead && health.hp == 0) {
        //         health.hp = health.maxHp
        //         health.status = .spawn
        //     }
        //     else if(health.hp >= health.maxHp && health.status != .alive) {
        //         health.hp = health.maxHp
        //         health.status = .alive
        //     }
        //     else {
        //         health.status = .alive
        //     }
        // }
    }

    struct HealtLogic: SystemBody {
        typealias Components = ComponentProxy<HealthComponent>

        @inlinable 
        @inline(__always)
        func execute(taskId: Int, components: Components) 
        {
            let _health = components
            // get fast proxy
            let health_fast = _health.fast

            if(health_fast.hp <= 0 && health_fast.status != .dead) {
                health_fast.hp = 0
                health_fast.status = .dead
            }
            else if(health_fast.status == .dead && health_fast.hp == 0) {
                health_fast.hp = health_fast.maxHp
                health_fast.status = .spawn
            }
            else if(health_fast.hp >= health_fast.maxHp && health_fast.status != .alive) {
                health_fast.hp = health_fast.maxHp
                health_fast.status = .alive
            }
            else {
                health_fast.status = .alive
            }
            
        }
    }
}