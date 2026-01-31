import ECScore

// @@ ############################################################################## 1

struct DataComponent: Component {
    static let defaultSeed: UInt32 = 340_383

    var thingy: Int = 0
    var dingy: Double = 0.0
    var mingy: Bool = false
    
    var seed: UInt32
    var rng: Xoshiro128
    var numgy: UInt32

    init(seed: UInt32 = Self.defaultSeed) {
        self.seed = seed
        var generator = Xoshiro128(seed: seed)
        self.numgy = generator.next()
        self.rng = generator
    }
}

// @@ ############################################################################## 1






// @@ ############################################################################## 2

struct EmptyComponent: Component {}

// @@ ############################################################################## 2





// @@ ############################################################################## 3

enum PlayerType {
    case ncp
    case monster
    case hero
}

struct PlayerComponent: Component {
    var rng: Xoshiro128 = Xoshiro128(seed: 0)
    var type: PlayerType = .ncp
}

enum StatusEffect {
    case spawn
    case dead
    case alive
}

struct HealthComponent: Component {
    var hp: Int = 0
    var maxHp: Int = 0
    var status: StatusEffect = .spawn
}

struct DamageComponent: Component {
    var atk: Int = 0
    var def: Int = 0
}

// @@ ############################################################################## 3




// @@ ############################################################################## 4

struct PositionComponent: Component {
    var x: Float = 0
    var y: Float = 0
}

// @@ ############################################################################## 4





// @@ ############################################################################## 5

struct SpriteComponent: Component {
    var character: Character = " "
}

// @@ ############################################################################## 5





// @@ ############################################################################## 6

struct VelocityComponent: Component {
    var vx: Float = 1
    var vy: Float = 1
}

// @@ ############################################################################## 6


