import ECScore
import Foundation

// global Setting
let clock = ContinuousClock()
struct GameSettings {
    let ttEn: Int
    var rng: Xoshiro128
    let complexFlag: Bool
}

@main
struct Game7Systems {
    public static func main() async throws {
        // ##################################################
        // parameter
            let ITER_NUM = 10
            let totalEntityNum = 4096 * 256
            let seed = UInt32(12345)
            let complexFlag = true
        // ##################################################

        for _ in 0..<ITER_NUM {
            var gs = GameSettings(ttEn: totalEntityNum, rng: Xoshiro128(seed: seed), complexFlag: complexFlag)
            run(&gs)
        }
        
    }
}


func run(_ gs: inout GameSettings) {
    // ---------------------------------------------------------
    // world
    // #####################################################################################
        var world = World(registry: makeBootedPlatform())
    // systems init
    // #####################################################################################
        let dmgSys = DmgSystem(base: world.base)
        let healthSys = HealthSystem(base: world.base)
        let dataSys = DataSystem(base: world.base)
        let mcSys = MoreComplexSystem(base: world.base)
        let mvSys = MoveSystem(base: world.base)
        let spriteSys = SpriteSystem(base: world.base)
        let renderSys = RenderSystem(base: world.base)
    // #####################################################################################
    // ---------------------------------------------------------

let t0 = clock.now
    // ---------------------------------------------------------
    // emplace
    // #####################################################################################
    // parameter
        let empToken = interop(world.base, 
            PlayerComponent.self, HealthComponent.self, DamageComponent.self, PositionComponent.self,
            DataComponent.self, SpriteComponent.self
        )
        let totalEntityNum = gs.ttEn
        var (heroCount, monsterCount, npcCount) = (0, 0, 0)
    // #####################################################################################
    // emplace-stage
        emplace(world.base, tokens: empToken) {
            entities, pack in
            var ( plSt, hSt, dmgSt, posSt, dataSt, spSt ) = pack.storages
            for i in 0..<totalEntityNum {
                var targetType: PlayerType? = nil

                // 1. 完全復刻 C++ 的取模優先權邏輯 (Modulo Chain)
                if i == 0 {
                    targetType = .hero
                } else if (i % 6) == 0 {
                    let roll = gs.rng.next() % 100
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

                    let (p, h, d, pos) = World.Spawner.spawnEntityComponent(tempRng: &gs.rng, type)
                    // 執行 ECScore 的指標寫入
                    let entity = entities.createEntity()
                    plSt.addComponent(entity, p)
                    hSt.addComponent(entity, h)
                    dmgSt.addComponent(entity, d)
                    posSt.addComponent(entity, pos)

                    // 注意：根據 C++ 邏輯，不符合 i % 2/4/6 的實體會被跳過
                    // 這就是所謂的 "Mixed Entities"：記憶體中會存在「空洞」或「非戰鬥實體」

                    guard gs.complexFlag else { continue }
                        
                    dataSt.addComponent(entity, DataComponent(seed: gs.rng.next()))
                    spSt.addComponent(entity, SpriteComponent(character: UInt8(ascii: " ")))
                }
            }
        }
    // #####################################################################################
    // ---------------------------------------------------------

let t1 = clock.now
    // ---------------------------------------------------------
    // system update
    // tick // set dt
    world.tick()
    // #####################################################################################
    // run-stage
        dmgSys.update(world)
        healthSys.update(world)
        dataSys.update(world)
        mcSys.update(world)
        mvSys.update(world)
        spriteSys.update(world)
        renderSys.update(world)
    // #####################################################################################
    // ---------------------------------------------------------

let t2 = clock.now
    print("entity create duration: ", t1 - t0)
    print("systems update duration: ", t2 - t1)
    print("(hero, monster, npc) : \((heroCount, monsterCount, npcCount))")
}
