import ECScore

// Validated BasePlatform
typealias VBPF = Validated<BasePlatform, Proof_Handshake, Platform_Facts>
func makeBootedPlatform() -> VBPF {
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

struct GameSettings {
    let iterId: Int
    let ttEn: Int
    let seed: UInt32
    let printWorldFlag: Bool
    let emplaceStrategy: emplaceStrategyProb

    enum emplaceStrategyProb: UInt32, CustomStringConvertible {
        case prob_000 = 0
        case prob_025 = 25
        case prob_050 = 50
        case prob_075 = 75
        case prob_100 = 100

        var description: String { "Prob(\(Double(self.rawValue) / 100))" }
    }
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
        let s02 = gs.emplaceStrategy
        let s03 = gs.ttEn
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
        res += "        emplaceStrategy : \(s02)" + "\n"
        res += "total entities number   : \(s03)" + "\n"
        res += "entity create duration  : \(s04)" + "\n"
        res += "systems update duration : \(s05)" + "\n"
        res += "(hero, monster, npc)    : \(s06)" + "\n"
        res += "======================================================\n"
        res += "  MoveSystem Duration   : \(s07)" + "\n"
        res += "  DataSystem Duration   : \(s08)" + "\n"
        res += "MCmplxSystem Duration   : \(s09)" + "\n"
        res += "HealthSystem Duration   : \(s10)" + "\n"
        res += "DamageSystem Duration   : \(s11)" + "\n"
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
