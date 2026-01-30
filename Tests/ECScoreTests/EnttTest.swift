import Testing
import Foundation
@testable import ECScore 

struct Velocity: Component {
    var vx: Float
    var vy: Float
}

struct Age: Component {
    let val: Int
}

struct Name: Component {
    let val: String
}

@Test func emplaceTest() async throws {
    let base = makeBootedPlatform()
    let ttokens = interop(
        base, Position.self, Velocity.self, MockComponentA.self, MockComponentB.self
    )

    emplace(base, tokens: ttokens) { 
        (entities, pack) in
        // storage pack
        var (st1, st2, st3, st4) = pack.storages
        let entityCount = 4096 * 16
        
        for _ in 0..<entityCount {
            let e = entities.createEntity()
            if Int.random(in: 0..<10) < 7 { 
                st1.addComponent(e, Position.init(x: Float.random(in: 0...10), y: Float.random(in: 0...10)))
                st2.addComponent(e, Velocity(vx: Float.random(in: 0...10), vy: Float.random(in: 0...10) ))
            }
            if Int.random(in: 0..<10) < 5 { 
                st3.addComponent(e, MockComponentA())
            }
            if Int.random(in: 0..<10) < 5 { 
                st4.addComponent(e, MockComponentB())
            }
        }
    }
    // #########################################################
    let clock = ContinuousClock()
    let dt = Float(1.0 / 120.0)
    let ttokens2 = interop(base, Position.self, Velocity.self)
    // #########################################################

    // // #####################
    // // ### Parallel Mode ###
    // // #####################
    // sleep(1)
    // let t0 = clock.now
    // await viewParallel(base: base, with: ttokens2) { 
    //     pos, vel in
    //     pos.pointee.x += vel.pointee.vx * dt
    //     pos.pointee.y += vel.pointee.vy * dt
    // } 
    // let t1 = clock.now
    // print("plan & exec:", t1 - t0)
    // sleep(1)
    for _ in 0..<100 {
    let start = clock.now
    view(base: base, with: ttokens2) { 
        pos, vel in
        pos.pointee.x += vel.pointee.vx * dt
        pos.pointee.y += vel.pointee.vy * dt
    }
    let end = clock.now
    print("plan & exec:", end - start)
    }
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
