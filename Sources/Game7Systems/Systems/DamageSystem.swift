import ECScore

struct DmgSystem {
    let dmgToken: (TypeToken<HealthComponent>, TypeToken<DamageComponent>)

    init(base: borrowing VBPF) {
        self.dmgToken = interop(base, HealthComponent.self, DamageComponent.self)
    }

    @inline(__always)
    func update(base: borrowing VBPF) 
    {
        view(base: base, with: dmgToken) 
        { _, health, damage in

            let totalDamage = damage.atk - damage.def
            if (health.hp > 0 && totalDamage > 0) {
                health.hp = max(health.hp - totalDamage, 0)
            }

        }
    }
}