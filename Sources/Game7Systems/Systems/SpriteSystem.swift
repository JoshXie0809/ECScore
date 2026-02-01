import ECScore

struct SpriteSystem {
    struct SpriteCharacter {
        // 使用 UInt8(ascii:) 直接定義，對齊 C++ 的 char 效能
        static let playerSprite: UInt8  = UInt8(ascii: "@")
        static let monsterSprite: UInt8 = UInt8(ascii: "k")
        static let npcSprite: UInt8     = UInt8(ascii: "h")
        static let graveSprite: UInt8   = UInt8(ascii: "|")
        static let spawnSprite: UInt8   = UInt8(ascii: "_")
        static let nonSprite: UInt8     = UInt8(ascii: " ")
    }

    let spriteToken: (TypeToken<SpriteComponent>, TypeToken<PlayerComponent>, TypeToken<HealthComponent>)

    init(base: borrowing VBPF) {
        self.spriteToken = interop(base, SpriteComponent.self, PlayerComponent.self, HealthComponent.self)
    }
    @inline(__always)
    func update(_ world: borrowing World) 
    {
        view(base: world.base, with: spriteToken) 
        { _, sprite, player, health in

            let ch: UInt8 = switch health.status {
            case .alive:
                switch player.type {
                case .hero:    SpriteCharacter.playerSprite
                case .monster: SpriteCharacter.monsterSprite
                case .npc:     SpriteCharacter.npcSprite
                }
            case .dead:  SpriteCharacter.graveSprite
            case .spawn: SpriteCharacter.spawnSprite
            }         

            sprite.character = ch
        }
        
    }
}
