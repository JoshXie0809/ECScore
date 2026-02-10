import ECScore

struct DmgSystem {
    let dmgToken: (TypeToken<HealthComponent>, TypeToken<DamageComponent>)

    init(base: borrowing VBPF) {
        self.dmgToken = interop(base, HealthComponent.self, DamageComponent.self)
    }

    @inline(__always)
    func update(_ world: borrowing World)
    {
        let logic = Self.DamageLogic()
        view(base: world.base, with: dmgToken, logic) 

        // view(base: world.base, with: dmgToken) 
        // { _, health, damage in
        //     let totalDamage = damage.atk - damage.def
        //     if (health.hp > 0 && totalDamage > 0) {
        //         health.hp = max(health.hp - totalDamage, 0)
        //     }
        // }
    }
    
    struct DamageLogic: SystemBody {
        typealias Components = (ComponentProxy<HealthComponent>, ComponentProxy<DamageComponent>)
        
        @inlinable 
        @inline(__always)
        func execute(taskId: Int, components: Components) {

            let (_health, _damage) = components
            // get fast proxy
            let (health_fast, damage_fast) = (_health.fast, _damage.fast)
            
            let totalDamage = damage_fast.atk - damage_fast.def
            if (health_fast.hp > 0 && totalDamage > 0) {
                health_fast.hp = max(health_fast.hp - totalDamage, 0)
            }

        }
    }
}