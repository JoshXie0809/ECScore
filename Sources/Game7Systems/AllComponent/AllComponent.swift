import ECScore

// @@ ############################################################################## 1
@FastProxy
public struct DataComponent: Component {
    public static let defaultSeed: UInt32 = 340_383

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
public struct EmptyComponent: Component {}

// @@ ############################################################################## 2





// @@ ############################################################################## 3

public enum PlayerType {
    case npc
    case monster
    case hero
}

@FastProxy
public struct PlayerComponent: Component {
    var rng: Xoshiro128 = Xoshiro128(seed: 0)
    var type: PlayerType = .npc
}

public enum StatusEffect {
    case spawn
    case dead
    case alive
}

@FastProxy
public struct HealthComponent: Component {
    var hp: Int = 0
    var maxHp: Int = 0
    var status: StatusEffect = .spawn
}

@FastProxy
public struct DamageComponent: Component {
    var atk: Int = 0
    var def: Int = 0
}

// @@ ############################################################################## 3




// @@ ############################################################################## 4

@FastProxy
public struct PositionComponent: Component {
    var x: Float = 0
    var y: Float = 0
}

// @@ ############################################################################## 4





// @@ ############################################################################## 5

@FastProxy
public struct SpriteComponent: Component {
    var character: UInt8 = UInt8(ascii: " ")
}

// @@ ############################################################################## 5





// @@ ############################################################################## 6

// @FastProxy is same as below, but I don't implement a lot of edge case
// so if has any error, just use defalut @DynamicLookup
public struct VelocityComponent: Component {
    var vx: Float = 1
    var vy: Float = 1
}

// or DIY
extension VelocityComponent: FastComponentProtocol {
    public struct ProxyMembers: FastProxyPointer{
        public typealias T = VelocityComponent
        @inline(__always) private let ptr: UnsafeMutablePointer<T>
        @inline(__always) 
        public init(ptr: UnsafeMutablePointer<T>) { self.ptr = ptr }

        @inline(__always) 
        public var vx: Float { 
            @inline(__always) _read {
                yield ptr.pointee.vx
            }
            @inline(__always) nonmutating _modify {
                yield &ptr.pointee.vx
            }
        }

        @inline(__always) 
        public var vy: Float { 
            @inline(__always) _read {
                yield ptr.pointee.vy
            }
            @inline(__always) nonmutating _modify {
                yield &ptr.pointee.vy
            }
        }
    }
}

// @@ ############################################################################## 6


// // testing myself
// struct MockA: Component {}
// struct MockB: Component {}
// struct MockC: Component {}
// struct MockD: Component {}
// struct MockE: Component {}


// // testing myself
// struct MockA1: Component {}
// struct MockB1: Component {}
// struct MockC1: Component {}
// struct MockD1: Component {}
// struct MockE1: Component {}
