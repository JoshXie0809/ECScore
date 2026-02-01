import ECScore

struct HealthSystem {
    let hToken: TypeToken<HealthComponent>

    init(base: borrowing VBPF) {
        self.hToken = interop(base, HealthComponent.self)
    }

    @inline(__always)
    func update(base: borrowing VBPF) 
    {
        view(base: base, with: hToken) 
        { _, health in

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