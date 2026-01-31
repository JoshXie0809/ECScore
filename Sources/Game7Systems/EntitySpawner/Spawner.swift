import ECScore

public class WorldSpawner {
    // 定義生成邊界常數
    static let maxX = 320
    static let maxY = 240
    
    // 使用你的 ECScore Registry
    let base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>
    let ttokens: (TypeToken<PlayerComponent>, TypeToken<HealthComponent>, TypeToken<DamageComponent>, TypeToken<PositionComponent>)

    public init(registry: consuming Validated<BasePlatform, Proof_Handshake, Platform_Facts>) {
        self.base = registry
        self.ttokens = interop(base, 
            PlayerComponent.self, HealthComponent.self,
            DamageComponent.self, PositionComponent.self
        )
    }

    public func spawnRandomEntity() {
        // 1. 先決定職業
        var tempRng = Xoshiro128(seed: UInt32.random(in: 0...UInt32.max))
        let roll = tempRng.next() % 100
        
        let type: PlayerType = (roll < 3) ? .npc : (roll < 30) ? .hero : .monster
        
        // 2. 根據職業分配組件 (模仿 C++ setComponents 邏輯)
        let hp: Int
        let atk: Int
        
        switch type {
        case .hero:
            hp = Int(tempRng.next() % 11 + 5) // 5-15
            atk = Int(tempRng.next() % 7 + 4) // 4-10
        case .monster:
            hp = Int(tempRng.next() % 9 + 4)  // 4-12
            atk = Int(tempRng.next() % 7 + 3) // 3-9
        case .npc:
            hp = Int(tempRng.next() % 7 + 6)  // 6-12
            atk = 0
        }

        emplace(base, tokens: ttokens) { entities, pack in
            var (playerST, healthST, dmgST, posST) = pack.storages
            let entity = entities.createEntity()

            playerST.addComponent(entity, PlayerComponent(type: type))
            healthST.addComponent(entity, HealthComponent(hp: hp, maxHp: hp))
            dmgST.addComponent(entity, DamageComponent(atk: atk))

            posST.addComponent(entity, 
                PositionComponent(
                    x: Float(tempRng.next() % UInt32(Self.maxX)), 
                    y: Float(tempRng.next() % UInt32(Self.maxY))
                )
            )
        }
    }
    
    @inline(__always)
    func viewWorldParallel(
        _ body: @escaping @Sendable (Int, ComponentProxy<PlayerComponent>, ComponentProxy<HealthComponent>, ComponentProxy<DamageComponent>, ComponentProxy<PositionComponent>) -> Void
    ) async {
        await viewParallel( base: self.base, with: self.ttokens, coresNum: 4 ) {
            tid, player, health, dmg, pos in
            body(tid, player, health, dmg, pos)
        }
    }

    
    func viewWorld(
        _ body: (Int, ComponentProxy<PlayerComponent>, ComponentProxy<HealthComponent>, ComponentProxy<DamageComponent>, ComponentProxy<PositionComponent>) -> Void
    )  {
        view( base: self.base, with: self.ttokens ) {
            tid, player, health, dmg, pos in
            body(tid, player, health, dmg, pos)
        }
    }

}