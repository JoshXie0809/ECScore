import ECScore
import Foundation

@main
struct Game7Systems {
    public static func main() async throws {
        
        let clock = ContinuousClock()
        let base = makeBootedPlatform()
        let world = WorldSpawner(registry: base)

        let t0 = clock.now

        for _ in 0..<(4096) {
            world.spawnRandomEntity()
        }

        let t1 = clock.now
        print(t1 - t0)

        world.viewWorld {
            taskId, player, hlth, dmg, pos in
            pos.x += 1
            pos.y -= 1
        }

        
        let t2 = clock.now
        print(t2 - t1)
    }
}











func makeBootedPlatform() -> Validated<BasePlatform, Proof_Handshake, Platform_Facts> {
    let base = BasePlatform()
    let registry = RegistryPlatform()
    let entities = EntityPlatForm_Ver0()
    
    // 建立初始環境：Registry(0), Entities(1)
    base.boot(registry: registry, entities: entities)

    var pf_val = Raw(value: base).upgrade(Platform_Facts.self)
    validate(validated: &pf_val, .handshake)

    // 被驗證可以 handshake 的平台
    guard case let .success(pf_handshake) = pf_val.certify(Proof_Handshake.self) else {
        fatalError()
    }

    return pf_handshake
}
