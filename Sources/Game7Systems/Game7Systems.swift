import ECScore
import Foundation

let clock = ContinuousClock()

@main
struct Game7Systems {
    public static func main() async throws {
        // ##################################################
        // parameter
            let ITER_NUM = 16
            let totalEntityNum = 4096 * 512
            let seed = UInt32(12345)
            let emplaceStrategy = GameSettings.emplaceStrategyProb.prob_100
            let printWorldFlag = false
        // ##################################################

        printSystemInfo()

        for iter in 0..<ITER_NUM {
            let gs = GameSettings(
                iterId: iter,
                ttEn: totalEntityNum, 
                seed: seed, 
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
    // resource for system
        var world = World(makeBootedPlatform())
        var rng = Xoshiro128(seed: gs.seed)
        let empToken: EMP_TOKEN = interop(world.base, 
            PlayerComponent.self, HealthComponent.self, 
            DamageComponent.self, PositionComponent.self,
            DataComponent.self, SpriteComponent.self, 
            DirectionComponent.self, EmptyComponent.self
        )
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
        let hmn = createEntities2(world, gs, &rng, empToken)
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
    let fakeDt = Duration.nanoseconds(1_000_000_000 / 120)
    world.tick(fakeDt)
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
func createEntities(
    _ world: borrowing World, _ gs: GameSettings, 
    _ rng: inout Xoshiro128, _ empToken: EMP_TOKEN
) -> (Int, Int, Int) 
{
    let totalEntityNum = gs.ttEn
    var (heroCount, monsterCount, npcCount) = (0, 0, 0)
    let prob = gs.emplaceStrategy.rawValue
    
    emplace(world.base, tokens: empToken) {
        entities, pack in
        var ( plSt, hSt, dmgSt, posSt, 
            dataSt, spSt, dirSt, emptySt ) = pack.storages
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

                let (p, h, d) = World.Spawner.spawnEntityComponent(&rng, type)

                let entity = entities.createEntity()
                plSt.addComponent(entity, p)
                hSt.addComponent(entity, h)
                dmgSt.addComponent(entity, d)
                spSt.addComponent(entity, SpriteComponent()) 

                let roll1 = rng.next() 
                let roll2 = rng.next()
                let roll3 = rng.next() 
                let roll4 = rng.next() 
                let roll5 = rng.next()

                if roll1 % 100 > prob { // empty
                    emptySt.addComponent(entity, EmptyComponent()) 
                    continue
                } 

                if (roll2 % 100 & 1) == 0 { // all-component
                    dataSt.addComponent(entity, DataComponent(seed: roll3))
                } 

                // minimal
                let pos = PositionComponent(
                    x: Float(roll4 % World.maxX), 
                    y: Float(roll5 % World.maxY)
                )

                posSt.addComponent(entity, pos)
                dirSt.addComponent(entity, DirectionComponent())    

            }
        }
    }
    return (heroCount, monsterCount, npcCount) 
}

typealias EMP_TOKEN = (
    TypeToken<PlayerComponent>, 
    TypeToken<HealthComponent>, 
    TypeToken<DamageComponent>, 
    TypeToken<PositionComponent>, 
    TypeToken<DataComponent>, 
    TypeToken<SpriteComponent>, 
    TypeToken<DirectionComponent>,
    TypeToken<EmptyComponent>
)

// same as bench-mark-logic
// https://github.com/abeimler/ecs_benchmark/blob/master/benchmark/benchmarks/BaseECSBenchmark.h#L185
// https://github.com/abeimler/ecs_benchmark/blob/master/benchmark/benchmarks/BaseECSBenchmark.h#L134
// I guess performance on table is remove from full / not add from empty?

@inline(__always) 
func createEntities2(
    _ world: borrowing World, _ gs: GameSettings, 
    _ rng: inout Xoshiro128, _ empToken: EMP_TOKEN
) -> (Int, Int, Int) 
{
    let totalEntityNum = gs.ttEn
    var (heroCount, monsterCount, npcCount) = (0, 0, 0)
    
    emplace(world.base, tokens: empToken) {
        entities, pack in
        var ( plSt, hSt, dmgSt, posSt, 
            dataSt, spSt, dirSt, _ ) = pack.storages
        var j = 0

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

                let (p, h, d) = World.Spawner.spawnEntityComponent(&rng, type)

                let entity = entities.createEntity()
                plSt.addComponent(entity, p)
                hSt.addComponent(entity, h)
                dmgSt.addComponent(entity, d)
                spSt.addComponent(entity, SpriteComponent()) 
                posSt.addComponent(entity, PositionComponent()) // 1
                dirSt.addComponent(entity, DirectionComponent()) // 2
                dataSt.addComponent(entity, DataComponent()) // 3

                if i >= (totalEntityNum / 2) && i <= (totalEntityNum * 3 / 4) {
                    if j % 10 == 0 {
                        if i % 17 == 0 {
                            plSt.removeComponent(entity)
                            hSt.removeComponent(entity)
                            dmgSt.removeComponent(entity)
                            spSt.removeComponent(entity)
                            dataSt.removeComponent(entity)
                            posSt.removeComponent(entity)
                            dirSt.removeComponent(entity)

                            switch type {
                            case .hero: heroCount -= 1
                            case .monster: monsterCount -= 1
                            case .npc: npcCount -= 1
                            }

                            entities.destroyEntity(entity)
                        } else {
                            if i % 7 == 0 {
                                posSt.removeComponent(entity)  // 1
                            }
                            if i % 11 == 0 {
                                dirSt.removeComponent(entity) // 2
                            }
                            if i % 13 == 0 {
                                dataSt.removeComponent(entity) // 3
                            }
                        }
                    }
                    j += 1
                }
            }
        }
    }
    return (heroCount, monsterCount, npcCount) 
}
