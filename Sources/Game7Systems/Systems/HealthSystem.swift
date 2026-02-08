import ECScore

public struct HealthSystem {
    let hToken: TypeToken<HealthComponent>

    init(base: borrowing VBPF) {
        self.hToken = interop(base, HealthComponent.self)
    }

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

    public struct HealtLogic: SystemBody {
        public typealias Components = ComponentProxy<HealthComponent>

        @inlinable 
        @inline(__always)
        public func execute(taskId: Int, components: Components) 
        {
            let health = components

            if(health.hp <= 0 && health.status != .dead) {
                health.hp = 0
                health.status = .dead
            }
            else if(health.status == .dead && health.hp == 0) {
                health.hp = health.maxHp
                health.status = .spawn
            }
            else if(health.hp >= health.maxHp && health.status != .alive) {
                health.hp = health.maxHp
                health.status = .alive
            }
            else {
                health.status = .alive
            }
            
        }
    }
}