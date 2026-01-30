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




// @Test func emplaceAndViewParallelTest() async throws {
//     let base = makeBootedPlatform()
//     let ttokens = interop(
//         base, Position.self, Velocity.self, Damage.self, Defence.self, Health.self, CharStatus.self
//     )

//     emplace(base, tokens: ttokens) { 
//         (entities, pack) in
//         // storage pack
//         var (pos, vel, dmg, def, hp, charStatus) = pack.storages
//         let entityCount = 4096 * 64 * 4 * 2
        
//         for i in 0..<entityCount {
//             let e = entities.createEntity()

//             if i % 2 == 0 {
//                 hp.addComponent(e, Health(hp: Int.random(in: 10...50)))
//                 charStatus.addComponent(e, CharStatus(status: .alive))
//             }
//             if i % 3 == 0 {
//                 pos.addComponent(e, Position.init(x: Float.random(in: 0...10), y: Float.random(in: 0...10)))
//                 vel.addComponent(e, Velocity(vx: Float.random(in: 0...10), vy: Float.random(in: 0...10) ))
//             }
//             if i % 4 == 0 { 
//                 dmg.addComponent(e, Damage(atk: Int.random(in: 10...30)))
//                 def.addComponent(e, Defence(def: Int.random(in: 5...10)))
//             }
//         }
//     }
//     // #########################################################
//     let clock = ContinuousClock()
//     let dt = Float(1.0 / 120.0)
//     let coresNum = 12
//     let parallel_deadCount = ResDeadCount(coresNum)
//     let parallel_checkDeadCount = ResDeadCount(coresNum)
//     let ttokens2 = interop(base, Position.self, Velocity.self, Health.self)
//     let ttokens3 = interop(base, Damage.self, Defence.self, Health.self)
//     let ttokens4 = interop(base, Health.self, CharStatus.self)
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
//             pack, pos, vel, health in
            
//             if health.pointee.hp > 0 {
//                 pos.pointee.x += vel.pointee.vx * dt
//                 pos.pointee.y += vel.pointee.vy * dt
//             }
//         }

//         // attack-defence system
//         await viewParallel(base: base, with: ttokens3, coresNum: coresNum) {
//             tid, dmg, def, health in
//             let totalDamage = dmg.pointee.atk - def.pointee.def // negative mean add hp
//             health.pointee.hp -= totalDamage
//         }

//         // charather-status
//         await viewParallel(base: base, with: ttokens4, coresNum: coresNum) {
//             tid, health, charStatus in

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
        base, Position.self, Velocity.self, Damage.self, Defence.self, Health.self, CharStatus.self
    )

    emplace(base, tokens: ttokens) { 
        (entities, pack) in
        // storage pack
        var (pos, vel, dmg, def, hp, charStatus) = pack.storages
        let entityCount = 4096 * 64 * 4 * 2
        
        for i in 0..<entityCount {
            let e = entities.createEntity()

            if i % 2 == 0 {
                hp.addComponent(e, Health(hp: Int.random(in: 10...50)))
                charStatus.addComponent(e, CharStatus(status: .alive))
            }
            if i % 3 == 0 {
                pos.addComponent(e, Position.init(x: Float.random(in: 0...10), y: Float.random(in: 0...10)))
                vel.addComponent(e, Velocity(vx: Float.random(in: 0...10), vy: Float.random(in: 0...10) ))
            }
            if i % 4 == 0 { 
                dmg.addComponent(e, Damage(atk: Int.random(in: 10...30)))
                def.addComponent(e, Defence(def: Int.random(in: 5...10)))
            }
        }
    }
    // #########################################################
    let clock = ContinuousClock()
    let dt = Float(1.0 / 120.0)
    var deadCount = 0
    var checkDeadCount = 0
    let ttokens2 = interop(base, Position.self, Velocity.self, Health.self)
    let ttokens3 = interop(base, Damage.self, Defence.self, Health.self)
    let ttokens4 = interop(base, Health.self, CharStatus.self)
    let ttokens5 = interop(base, CharStatus.self)
    // #########################################################

    // ###################################
    // Single thread
    // ###################################

    let start = clock.now
    for _ in 0..<2 {
        // move sys
        view(base: base, with: ttokens2) { 
            _, pos, vel, health in
            if health.pointee.hp > 0 {
                pos.pointee.x += vel.pointee.vx * dt
                pos.pointee.y += vel.pointee.vy * dt
            }
        }

        // attack-defence system
        view(base: base, with: ttokens3) {
            _, dmg, def, health in
            let totalDamage = dmg.pointee.atk - def.pointee.def // negative mean add hp
            health.pointee.hp -= totalDamage
        }
        
        // charather-status
        view(base: base, with: ttokens4) {
            _, health, charStatus in
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

    view(base: base, with: ttokens5) {
        _, charStatus in
        if charStatus.pointee.status == .dead {
            checkDeadCount += 1
        }
    }
    let end = clock.now
    #expect(deadCount == checkDeadCount)

    print("plan & exec:", end - start)
}



@Test func trailingZeroBitCountTest() async throws {
    var mask: UInt64 = 0
    #expect(mask.trailingZeroBitCount == 64)

    mask = 1
    #expect(mask.trailingZeroBitCount == 0)
}

// @Test func emplaceSpeedTest1M() async throws {
//     let base = makeBootedPlatform()
    
//     // 1. 預備型別權限
//     let ttokens = interop(
//         base, 
//         MockComponentA.self, // st1
//         MockComponentB.self, // st2
//         Position.self,       // st3
//         Velocity.self,       // st4
//         Age.self,            // st5
//         Name.self            // st6
//     )

//     let entityCount = 1_000_000
//     print("--- Starting Speed Test: \(entityCount) Entities ---")
    
//     let clock = ContinuousClock()
//     let startTime = clock.now

//     // 2. 執行大規模掛載
//     emplace(base, tokens: ttokens) { (entities, pack) in
//         // 利用 Swift 2026 參數包解構存儲器
//         var (stA, stB, stPos, stVel, stAge, stName) = pack.storages
        
//         for i in 0..<entityCount {
//             // 生成實體 ID
//             let e = entities.createEntity()
            
//             // 每個實體都掛載基礎組件 (寫入連續陣列)
//             stPos.addComponent(e, Position(x: Float(i), y: Float(i)))
//             stAge.addComponent(e, Age(val: i % 100))
            
//             // 模擬稀疏分佈 (測試 Sparse Set 的跳轉與 Page 建立)
//             if i % 10 == 0 {
//                 stA.addComponent(e, MockComponentA())
//                 stName.addComponent(e, Name(val: "Entity_\(i)"))
//             }
            
//             if i % 100 == 0 {
//                 stB.addComponent(e, MockComponentB())
//                 stVel.addComponent(e, Velocity(val: Double(i) * 0.01))
//             }
//         }
//     }
    
//     let endTime = clock.now
//     let duration = endTime - startTime
    
//     print("Total time for 1 million emplace: \(duration)")
//     print("--------------------------------------------------")

//     // 3. 驗證數據完整性 (檢查 activeEntityCount 是否正確)
//     let (t1, t2, t3, t4, t5, t6) = ttokens
//     #expect(base.getStorage(token: t3).activeEntityCount == 1_000_000) // Position
//     #expect(base.getStorage(token: t5).activeEntityCount == 1_000_000) // Age
//     #expect(base.getStorage(token: t1).activeEntityCount == 100_000)  // MockA
//     #expect(base.getStorage(token: t6).activeEntityCount == 100_000)  // Name
//     #expect(base.getStorage(token: t2).activeEntityCount == 10_000)   // MockB
//     #expect(base.getStorage(token: t4).activeEntityCount == 10_000)   // Velocity
// }
    