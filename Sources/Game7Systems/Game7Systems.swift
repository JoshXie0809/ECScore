import ECScore
import Foundation

@main
struct Game7Systems {
    public static func main() async throws {
        // ##################################################
        // ##################################################
        // parameter
        let ITER_NUM = 10
        let totalEntityNum = 4096 * 256
        let seed = UInt32(12345)
        // ##################################################
        // ##################################################

        for _ in 0..<ITER_NUM {
            var rng = Xoshiro128(seed: seed)
            run(ttEn: totalEntityNum, rng: &rng)
        }
    }
}








func run(ttEn: Int, rng: inout Xoshiro128) {
let clock = ContinuousClock()
    // ---------------------------------------------------------
    // world
    // #####################################################################################
    let world = WorldSpawner(registry: makeBootedPlatform())
    // systems init
    // #####################################################################################
    let dmgSys = DmgSystem(base: world.base)
    let healthSys = HealthSystem(base: world.base)
    let dataSys = DataSystem(base: world.base)
    let mcSys = MoreComplexSystem(base: world.base)
    let mvSys = MoveSystem(base: world.base)
    // #####################################################################################
    // ---------------------------------------------------------

let t0 = clock.now
    // ---------------------------------------------------------
    // emplace
    // #####################################################################################
    // parameter
    let empToken = interop(world.base, PlayerComponent.self, HealthComponent.self, DamageComponent.self, PositionComponent.self)
    let totalEntityNum = ttEn
    var (heroCount, monsterCount, npcCount) = (0, 0, 0)
    // #####################################################################################
    // emplace-stage
    emplace(world.base, tokens: empToken) {
        entities, pack in
        var (plSt, hSt, dmgSt, posSt) = pack.storages
        for i in 0..<totalEntityNum {
            var targetType: PlayerType? = nil

            // 1. 完全復刻 C++ 的取模優先權邏輯 (Modulo Chain)
            if i == 0 {
                targetType = .hero
            } else if (i % 6) == 0 {
                let roll = rng.next() % 100
                targetType = (roll < 3) ? .npc : (roll < 30) ? .hero : .monster
            } else if (i % 4) == 0 {
                targetType = .hero
            } else if (i % 2) == 0 {
                targetType = .monster
            }

            if let type = targetType {
                switch type {
                case .hero: heroCount += 1
                case .monster: monsterCount += 1
                case .npc: npcCount += 1
                }

                let (p, h, d, pos) = WorldSpawner.spawnEntityComponent(tempRng: &rng, type)

                // 執行 ECScore 的指標寫入
                let entity = entities.createEntity()
                plSt.addComponent(entity, p)
                hSt.addComponent(entity, h)
                dmgSt.addComponent(entity, d)
                posSt.addComponent(entity, pos)
            }
            
            // 注意：根據 C++ 邏輯，不符合 i % 2/4/6 的實體會被跳過
            // 這就是所謂的 "Mixed Entities"：記憶體中會存在「空洞」或「非戰鬥實體」
        }
    }
    // #####################################################################################
    // ---------------------------------------------------------

let t1 = clock.now
    // ---------------------------------------------------------
    // system update
    // #####################################################################################
    // parameter
    let dt = clock.now - t0
    // #####################################################################################
    // run-stage
    dmgSys.update(base: world.base)
    healthSys.update(base: world.base)
    dataSys.update(base: world.base, dt: dt)
    mcSys.update(base: world.base)
    mvSys.update(base: world.base, dt: dt)
    // #####################################################################################
    // ---------------------------------------------------------

let t2 = clock.now
    print("entity create duration: ", t1 - t0)
    print("systems update duration: ", t2 - t1)
    print("(hero, monster, npc) : \((heroCount, monsterCount, npcCount))")
}
