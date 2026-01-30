import Testing
import Foundation
@testable import ECScore 

struct Velocity: Component {
    var vx: Float
    var vy: Float
}

struct Damage: Component {
    var atk: Int
}

struct Defence: Component {
    var def: Int
}

struct Health: Component {
    var hp: Int
}

struct CharStatus: Component {
    var status: Status

    enum Status {
        case alive
        case dead
        case deadEdge
    }
}

struct BattleTag: Component {}




// @Test func emplaceAndViewParallelTest() async throws {
//     let base = makeBootedPlatform()
//     let ttokens = interop(
//         base, Position.self, Velocity.self, Damage.self, Defence.self, Health.self, CharStatus.self, BattleTag.self,
//         MockComponentA.self, MockComponentB.self, MockComponentC.self, MockComponentD.self, MockComponentE.self
//     )

//     emplace(base, tokens: ttokens) { (entities, pack) in
//         var (pos, vel, dmg, def, hp, charStatus, btag,
//             a, b, c, d, etag) = pack.storages
//         let entityCount = 4096 * 256 * 2
//         for _ in 0..<entityCount {
//             let e = entities.createEntity()
//             let roll = Int.random(in: 1...140)
            
//             // 所有實體都具備基礎的物理與狀態組件（達到 100% 密度）
//             pos.addComponent(e, Position(x: Float.random(in: 0...320), y: Float.random(in: 0...240)))
//             vel.addComponent(e, Velocity(vx: Float.random(in: 0...10), vy: Float.random(in: 0...10)))
//             charStatus.addComponent(e, CharStatus(status: .alive))

//             if roll <= 3 { // NPC
//                 hp.addComponent(e, Health(hp: Int.random(in: 6...12)))
//                 dmg.addComponent(e, Damage(atk: 0)) // NPC 不攻擊
//                 def.addComponent(e, Defence(def: Int.random(in: 3...8)))
//                 a.addComponent(e, MockComponentA())
//             } else if roll <= 30 { // Hero
//                 hp.addComponent(e, Health(hp: Int.random(in: 5...15)))
//                 dmg.addComponent(e, Damage(atk: Int.random(in: 4...10)))
//                 def.addComponent(e, Defence(def: Int.random(in: 2...6)))
//                 btag.addComponent(e, BattleTag())
//                 b.addComponent(e, MockComponentB())
                
//             } else if roll <= 100 { // Monster
//                 hp.addComponent(e, Health(hp: Int.random(in: 4...12)))
//                 dmg.addComponent(e, Damage(atk: Int.random(in: 3...9)))
//                 def.addComponent(e, Defence(def: Int.random(in: 2...8)))
//                 btag.addComponent(e, BattleTag())
//                 c.addComponent(e, MockComponentC())

//             } else if roll <= 120 {
//                 d.addComponent(e, MockComponentD())

//             } else {
//                 etag.addComponent(e, MockComponentE())
//             }
//         }
//     }
//     // #########################################################
//     let clock = ContinuousClock()
//     let dt = Float(1.0 / 120.0)
//     let coresNum = 12
//     let parallel_deadCount = ResDeadCount(coresNum)
//     let parallel_checkDeadCount = ResDeadCount(coresNum)
//     let ttokens2 = interop(base, Position.self, Velocity.self)
//     let ttokens3 = interop(base, Damage.self, Defence.self, Health.self, CharStatus.self)
//     let ttokens5 = interop(base, CharStatus.self)
//     // #########################################################

//     // #####################
//     // ### Parallel Mode ###
//     // #####################
//     final class ResDeadCount: @unchecked Sendable {
//         private var deadCount: UnsafeMutableBufferPointer<PaddedInt>
//         private let count: Int
//         init(_ count: Int) { 
//             let ptr = UnsafeMutablePointer<PaddedInt>.allocate(capacity: count)
//             ptr.initialize(repeating: PaddedInt(), count: count)
//             self.deadCount = UnsafeMutableBufferPointer(start: ptr, count: count)
//             self.count = count
//         }
        
//         deinit {
//             deadCount.baseAddress?.deallocate()
//         }

//         // 提供一個方便的累加方法
//         func add(at tid: Int) {
//             deadCount[tid].value += 1
//         }

//         var totalDead: Int {
//             var total = 0
//             for i in 0..<count {
//                 total += deadCount[i].value
//             }
//             return total
//         }
//     }

//     struct PaddedInt {
//         var value: Int
//         var padding: (Int, Int, Int, Int, Int, Int, Int) // 補齊到 64 bytes
//         @inlinable
//         init() {
//             self.value = 0
//             self.padding = (0, 0, 0, 0, 0, 0, 0)
//         }
//     }

//     let t0 = clock.now
//     for _ in 0..<2 {
//         // move sys
//         await viewParallel(base: base, with: ttokens2, coresNum: coresNum) { 
//             tid, pos, vel in
//             pos.pointee.x += vel.pointee.vx * dt
//             pos.pointee.y += vel.pointee.vy * dt
            
//         }

        
//         await viewParallel(base: base, with: ttokens3, coresNum: coresNum) {
//             tid, dmg, def, health, charStatus in

//             // attack-defence system
//             let totalDamage = dmg.pointee.atk - def.pointee.def // negative mean add hp
//             health.pointee.hp -= totalDamage

//             // charather-status
//             if health.pointee.hp <= 0 {
//                 health.pointee.hp = 0
//                 switch charStatus.pointee.status {
//                 case .alive:
//                     // change to dead edge
//                     charStatus.pointee.status = .deadEdge
//                 case .deadEdge:
//                     charStatus.pointee.status = .dead
//                     parallel_deadCount.add(at: tid)
//                 case .dead:
//                     charStatus.pointee.status = .dead
//                 } 
//             }
//             else {
//                 switch charStatus.pointee.status {
//                 case .dead:
//                     health.pointee.hp = 0
//                 case .deadEdge:
//                     charStatus.pointee.status = .alive
//                 case .alive:
//                     charStatus.pointee.status = .alive
//                 }
//             }
//         }
//     }

//     // 2-frame finished
//     await viewParallel(base: base, with: ttokens5, coresNum: coresNum) {
//         tid, charStatus  in
//         if charStatus.pointee.status == .dead {
//             parallel_checkDeadCount.add(at: tid)
//         }
//     }

//     #expect(parallel_deadCount.totalDead == parallel_checkDeadCount.totalDead)
//     _fixLifetime(parallel_deadCount)
//     _fixLifetime(parallel_checkDeadCount)
    
//     let t1 = clock.now
//     print("plan & exec:", t1 - t0)
//     print(parallel_deadCount.totalDead)
    
// }










@Test func emplaceAndViewTest() async throws {
    let base = makeBootedPlatform()
    let ttokens = interop(
        base, Position.self, Velocity.self, Damage.self, Defence.self, Health.self, CharStatus.self, BattleTag.self,
        MockComponentA.self, MockComponentB.self, MockComponentC.self, MockComponentD.self, MockComponentE.self
    )

    emplace(base, tokens: ttokens) { (entities, pack) in
        var (pos, vel, dmg, def, hp, charStatus, btag,
            a, b, c, d, etag) = pack.storages
        let entityCount = 4096 * 16
        for _ in 0..<entityCount {
            let e = entities.createEntity()
            let roll = Int.random(in: 1...140)
            
            // 所有實體都具備基礎的物理與狀態組件（達到 100% 密度）
            pos.addComponent(e, Position(x: Float.random(in: 0...320), y: Float.random(in: 0...240)))
            vel.addComponent(e, Velocity(vx: Float.random(in: 0...10), vy: Float.random(in: 0...10)))
            charStatus.addComponent(e, CharStatus(status: .alive))

            if roll <= 3 { // NPC
                hp.addComponent(e, Health(hp: Int.random(in: 6...12)))
                dmg.addComponent(e, Damage(atk: 0)) // NPC 不攻擊
                def.addComponent(e, Defence(def: Int.random(in: 3...8)))
                a.addComponent(e, MockComponentA())
            } else if roll <= 30 { // Hero
                hp.addComponent(e, Health(hp: Int.random(in: 5...15)))
                dmg.addComponent(e, Damage(atk: Int.random(in: 4...10)))
                def.addComponent(e, Defence(def: Int.random(in: 2...6)))
                btag.addComponent(e, BattleTag())
                b.addComponent(e, MockComponentB())
                
            } else if roll <= 100 { // Monster
                hp.addComponent(e, Health(hp: Int.random(in: 4...12)))
                dmg.addComponent(e, Damage(atk: Int.random(in: 3...9)))
                def.addComponent(e, Defence(def: Int.random(in: 2...8)))
                btag.addComponent(e, BattleTag())
                c.addComponent(e, MockComponentC())

            } else if roll <= 120 {
                d.addComponent(e, MockComponentD())

            } else {
                etag.addComponent(e, MockComponentE())
            }
        }
    }
    // #########################################################
    let clock = ContinuousClock()
    let dt = Float(1.0 / 120.0)
    var deadCount = 0
    var checkDeadCount = 0
    let ttokens2 = interop(base, Position.self, Velocity.self)
    let ttokens3 = interop(base, Damage.self, Defence.self, Health.self, CharStatus.self, BattleTag.self)
    let ttokens4 = interop(base, CharStatus.self)
    // #########################################################

    // ###################################
    // Single thread
    // ###################################

    let start = clock.now
    for _ in 0..<2 {
        // move sys
        view(base: base, with: ttokens2) { 
            _, pos, vel in
            pos.pointee.x += vel.pointee.vx * dt
            pos.pointee.y += vel.pointee.vy * dt
        }
        
        view(base: base, with: ttokens3) {
            _, dmg, def, health, charStatus, _btag in
            // attack-defence system
            let totalDamage = dmg.pointee.atk - def.pointee.def // negative mean add hp
            health.pointee.hp -= totalDamage

            // charather-status
            if health.pointee.hp <= 0 {
                health.pointee.hp = 0
                switch charStatus.pointee.status {
                case .alive:
                    // change to dead edge
                    charStatus.pointee.status = .deadEdge
                case .deadEdge:
                    charStatus.pointee.status = .dead
                    deadCount += 1
                case .dead:
                    charStatus.pointee.status = .dead
                } 
            }
            else {
                switch charStatus.pointee.status {
                case .dead:
                    health.pointee.hp = 0
                case .deadEdge:
                    charStatus.pointee.status = .alive
                case .alive:
                    charStatus.pointee.status = .alive
                }
            }
        }
    }

    view(base: base, with: ttokens4) {
        _, charStatus in
        if charStatus.pointee.status == .dead {
            checkDeadCount += 1
        }
    }
    let end = clock.now
    #expect(deadCount == checkDeadCount)
    print("total dead:", deadCount)
    print("plan & exec:", end - start)
}




@Test func trailingZeroBitCountTest() async throws {
    var mask: UInt64 = 0
    #expect(mask.trailingZeroBitCount == 64)

    mask = 1
    #expect(mask.trailingZeroBitCount == 0)
}


