import ECScore

struct SpriteSystem {
    struct SpriteCharacter {
        static let playerSprite: Character = "@"
        static let monsterSprite: Character = "k"
        static let npcSprite: Character = "h"
        static let graveSprite: Character = "|"
        static let spawnSprite: Character = "_"
        static let nonSprite: Character = " "
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

            let ch: Character = switch health.status {
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
