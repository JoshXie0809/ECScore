import ECScore

public class WorldSpawner {
    // 定義生成邊界常數
    static let maxX = 320
    static let maxY = 240
    
    // 使用你的 ECScore Registry
    let base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>
    public init(registry: consuming Validated<BasePlatform, Proof_Handshake, Platform_Facts>) {
        self.base = registry
    }

    static func spawnEntityComponent(tempRng: inout Xoshiro128, _ type: PlayerType) -> (PlayerComponent, HealthComponent, DamageComponent, PositionComponent)
    {
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

        let player = PlayerComponent(type: type)
        let health = HealthComponent(hp: hp, maxHp: hp)
        let dmg = DamageComponent(atk: atk)
        let pos = PositionComponent(
                    x: Float(tempRng.next() % UInt32(Self.maxX)), 
                    y: Float(tempRng.next() % UInt32(Self.maxY))
                )

        return (player, health, dmg, pos)
    }

}