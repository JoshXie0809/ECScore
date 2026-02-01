import ECScore
import Foundation

// global Setting
let clock = ContinuousClock()
struct GameSettings {
    let iterId: Int
    let ttEn: Int
    let seed: UInt32
    let complexFlag: Bool
    let printWorldFlag: Bool
    let emplaceStrategy: Int
}

@main
struct Game7Systems {
    public static func main() async throws {
        // ##################################################
        // parameter
            let ITER_NUM = 16
            let totalEntityNum = 4096 * 512
            let seed = UInt32(12345)
            let emplaceStrategy = 1
            let complexFlag = true
            let printWorldFlag = false
        // ##################################################

        for iter in 0..<ITER_NUM {
            let gs = GameSettings(
                iterId: iter,
                ttEn: totalEntityNum, seed: seed, 
                complexFlag: complexFlag, 
                printWorldFlag: printWorldFlag,
                emplaceStrategy: emplaceStrategy
            )
            print(run(gs))
        }
        
    }
}

func run(_ gs: GameSettings) -> RunResult {
    // ---------------------------------------------------------
    // world
    // #####################################################################################
        var world = World(makeBootedPlatform())
        var rng = Xoshiro128(seed: gs.seed)
    // systems init
    // #####################################################################################
        let dmgSys = DmgSystem(base: world.base)
        let healthSys = HealthSystem(base: world.base)
        let mcSys = MoreComplexSystem(base: world.base)
        let dataSys = DataSystem(base: world.base)
        let mvSys = MoveSystem(base: world.base)
        let spriteSys = SpriteSystem(base: world.base)
        let renderSys = RenderSystem(base: world.base)
    // #####################################################################################

// ---------------------------------------------------------
let ta0 = clock.now
// ---------------------------------------------------------        


    // #####################################################################################
    // create-entities-stage
    let hmn = createEntities(world, gs, &rng)
    // #####################################################################################


// ---------------------------------------------------------
let ta1 = clock.now
// ---------------------------------------------------------

// ---------------------------------------------------------
let tb0 = clock.now
// ---------------------------------------------------------

// bench-mark-system-order

// m_systems.emplace_back(createMovementSystem(m_entities));
// m_systems.emplace_back(createDataSystem(m_entities));

// if (m_addMoreComplexSystem == add_more_complex_system_t::UseMoreComplexSystems) {
//   m_systems.emplace_back(createMoreComplexSystem(m_entities));
//   m_systems.emplace_back(createHealthSystem(m_entities));
//   m_systems.emplace_back(createDamageSystem(m_entities));
//   m_systems.emplace_back(createSpriteSystem(m_entities));
//   m_systems.emplace_back(createRenderSystem(m_entities));
// }


    // system update
    // tick // set dt
    world.tick()
    // #####################################################################################
    // run-stage
        let sys1 = RunResult.durationHelper(mvSys.update, world)
        let sys2 = RunResult.durationHelper(dataSys.update, world)
        let sys3 = RunResult.durationHelper(mcSys.update, world)
        let sys4 = RunResult.durationHelper(healthSys.update, world)
        let sys5 = RunResult.durationHelper(dmgSys.update, world)
        let sys6 = RunResult.durationHelper(spriteSys.update, world)
        let sys7 = RunResult.durationHelper(renderSys.update, world)
        let allSysDuration = (sys1, sys2, sys3, sys4, sys5, sys6, sys7)
    // #####################################################################################


// ---------------------------------------------------------
let tb1 = clock.now
// ---------------------------------------------------------

    return RunResult(
        gs: gs, 
        d1: ta1-ta0, 
        d2: tb1-tb0, 
        hmn: hmn, 
        rs: world.renderString,
        alld: allSysDuration
    )
}

@inline(__always) 
func createEntities(_ world: borrowing World, _ gs: GameSettings, _ rng: inout Xoshiro128) -> (Int, Int, Int) {
    let empToken = interop(world.base, 
        PlayerComponent.self, HealthComponent.self, DamageComponent.self, PositionComponent.self,
        DataComponent.self, SpriteComponent.self, DirectionComponent.self
    )

    let totalEntityNum = gs.ttEn
    var (heroCount, monsterCount, npcCount) = (0, 0, 0)
    
    emplace(world.base, tokens: empToken) {
        entities, pack in
        var ( plSt, hSt, dmgSt, posSt, dataSt, spSt, dirSt ) = pack.storages
        for i in 0..<totalEntityNum {
            var targetType: PlayerType? = nil

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

                let (p, h, d, pos) = World.Spawner.spawnEntityComponent(tempRng: &rng, type)

                let entity = entities.createEntity()
                plSt.addComponent(entity, p)
                hSt.addComponent(entity, h)
                dmgSt.addComponent(entity, d)
                posSt.addComponent(entity, pos)
                guard gs.complexFlag else { continue }
                switch gs.emplaceStrategy {
                case 1 : 
                    dataSt.addComponent(entity, DataComponent(seed: rng.next()))
                    spSt.addComponent(entity, SpriteComponent())
                    dirSt.addComponent(entity, DirectionComponent())

                case 2 : 
                    if rng.next() % 100 < 50 { dataSt.addComponent(entity, DataComponent(seed: rng.next())) }
                    if rng.next() % 100 < 50 { spSt.addComponent(entity, SpriteComponent()) }
                    if rng.next() % 100 < 50 { dirSt.addComponent(entity, DirectionComponent()) }

                default: fatalError()
                }
                
            }
        }
    }
    return (heroCount, monsterCount, npcCount) 
}
