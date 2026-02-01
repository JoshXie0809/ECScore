import ECScore

struct World: ~Copyable {
    static let maxX = UInt32(320)
    static let maxY = UInt32(240)

    private var resource: World.Resource
    var dt: Duration { resource.dt }
    var renderString: String { resource.frameBuffer.renderToString() }
    var frameBuffer: FrameBuffer { resource.frameBuffer }

    // 使用你的 ECScore Registry
    let base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>

    public init(_ base: consuming Validated<BasePlatform, Proof_Handshake, Platform_Facts>) {
        self.base = base
        self.resource = Resource()
    }

    mutating func tick(_ fakeDt: Duration? = nil) {
        let now = clock.now
        if let dt = fakeDt {
            self.resource.dt = dt
        } else {
            self.resource.dt = now - self.resource.prev
        }
        self.resource.prev = now
    }
  
    struct Resource {
        var prev: ContinuousClock.Instant = clock.now
        var dt: Duration = .zero
        let frameBuffer: FrameBuffer = FrameBuffer(width: World.maxX, height: World.maxY)
    }

    struct Spawner {
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
                        x: Float(tempRng.next() % UInt32(World.maxX)), 
                        y: Float(tempRng.next() % UInt32(World.maxY))
                    )

            return (player, health, dmg, pos)
        }
    }
    
}