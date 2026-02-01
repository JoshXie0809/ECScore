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
}

@main
struct Game7Systems {
    public static func main() async throws {
        // ##################################################
        // parameter
            let ITER_NUM = 16
            let totalEntityNum = 4096 * 256
            let seed = UInt32(12345)
            let complexFlag = true
            let printWorldFlag = false
        // ##################################################

        for iter in 0..<ITER_NUM {
            let gs = GameSettings(
                iterId: iter,
                ttEn: totalEntityNum, seed: seed, 
                complexFlag: complexFlag, printWorldFlag: printWorldFlag
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

let t0 = clock.now
    // ---------------------------------------------------------
    // emplace
    // #####################################################################################
    // parameter
        let empToken = interop(world.base, 
            PlayerComponent.self, HealthComponent.self, DamageComponent.self, PositionComponent.self,
            DataComponent.self, SpriteComponent.self, DirectionComponent.self
        )
        let totalEntityNum = gs.ttEn
        var (heroCount, monsterCount, npcCount) = (0, 0, 0)
    // #####################################################################################
    // emplace-stage
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
                        
                    dataSt.addComponent(entity, DataComponent(seed: rng.next()))
                    spSt.addComponent(entity, SpriteComponent(character: UInt8(ascii: " ")))
                    dirSt.addComponent(entity, DirectionComponent(vx: 0, vy: 0))
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
        let sys1 = RunResult.durationHelper(dmgSys.update, world)
        let sys2 = RunResult.durationHelper(healthSys.update, world)
        let sys3 = RunResult.durationHelper(dataSys.update, world)
        let sys4 = RunResult.durationHelper(mcSys.update, world)
        let sys5 = RunResult.durationHelper(mvSys.update, world)
        let sys6 = RunResult.durationHelper(spriteSys.update, world)
        let sys7 = RunResult.durationHelper(renderSys.update, world)
        let allSysDuration = (sys1, sys2, sys3, sys4, sys5, sys6, sys7)
    // #####################################################################################
    // ---------------------------------------------------------

let t2 = clock.now
    return RunResult(
        gs: gs, 
        d1: t1-t0, 
        d2: t2-t1, 
        hmn: (heroCount, monsterCount, npcCount), 
        rs: world.renderString,
        alld: allSysDuration
    )
}

struct RunResult: CustomStringConvertible {
    let gs: GameSettings
    let renderString: String
    let createEntityDuration: Duration
    let updateEntityDuration: Duration
    let hmn: (Int, Int, Int)
    let allSysDuration: (Duration, Duration, Duration, Duration, Duration, Duration, Duration)

    init(gs: GameSettings, d1: Duration, d2: Duration, hmn: (Int, Int, Int), rs: String, 
        alld: (Duration, Duration, Duration, Duration, Duration, Duration, Duration)
    ) {
        self.gs = gs
        self.createEntityDuration = d1
        self.updateEntityDuration = d2
        self.renderString = rs
        self.hmn = hmn
        self.allSysDuration = alld
    }

    var description: String {
        let s01 = gs.iterId
        let s02 = gs.ttEn
        let s03 = gs.complexFlag
        let s04 = createEntityDuration
        let s05 = updateEntityDuration
        let s06 = hmn
        let s07 = allSysDuration.0
        let s08 = allSysDuration.1
        let s09 = allSysDuration.2
        let s10 = allSysDuration.3
        let s11 = allSysDuration.4
        let s12 = allSysDuration.5
        let s13 = allSysDuration.6
        var res = ""
        res += "======================================================\n"
        res += "                 iterId : \(s01)" + "\n"
        res += "total entities number   : \(s02)" + "\n"
        res += "is complex(7 system)?   : \(s03)" + "\n"
        res += "entity create duration  : \(s04)" + "\n"
        res += "systems update duration : \(s05)" + "\n"
        res += "(hero, monster, npc)    : \(s06)" + "\n"
        res += "======================================================\n"
        res += "DamageSystem Duration   : \(s07)" + "\n"
        res += "HealthSystem Duration   : \(s08)" + "\n"
        res += "  DataSystem Duration   : \(s09)" + "\n"
        res += "MCmplxSystem Duration   : \(s10)" + "\n"
        res += "  MoveSystem Duration   : \(s11)" + "\n"
        res += "SpriteSystem Duration   : \(s12)" + "\n"
        res += "RenderSystem Duration   : \(s13)" + "\n"
        res += "======================================================\n"
        return res
    }
    @inline(__always)
    static func durationHelper(_ system: (borrowing World) -> Void, _ world: borrowing World ) -> Duration {
        let t0 = clock.now
        system(world)
        return clock.now - t0
    }
}