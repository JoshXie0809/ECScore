// import Testing
// import Foundation
// @testable import ECScore

// @Test func testFragmentationAndRecycling() async throws {
//     // ----------------------------------------------------------------
//     // 1. 初始化戰場：建立 100,000 個實體
//     // ----------------------------------------------------------------
//     var storage = PFStorage<Position>()
//     let entities = Entities()
//     let initialCount = 100_000
    
//     // 紀錄時間：初始配置
//     let eids = entities.spawn(initialCount)
    
//     for i in 0..<initialCount {
//         storage.add(eid: eids[i], component: Position(x: Float(i), y: Float(i)))
//     }
    
//     print("✅ Initialized \(initialCount) entities.")

//     // ----------------------------------------------------------------
//     // 2. 製造災難：模擬大規模「跳躍式」刪除 (碎片化攻擊)
//     // ----------------------------------------------------------------
//     // 每隔 2 個刪除 1 個，這會在記憶體中製造出最大量的「空洞」
//     // 這比刪除後半部更狠，因為它強迫系統處理不連續的記憶體頁面
//     var removedCount = 0
//     for i in stride(from: 0, to: initialCount, by: 2) {
//         let eid = eids[i]
//         storage.remove(eid: eid)
//         entities.despawn(eid)
//         removedCount += 1
//     }
    
//     print("⚠️ Removed \(removedCount) entities (Fragmentation created).")
    
//     // ----------------------------------------------------------------
//     // 3. 測試回收機制：重新生成實體，看 ID 是否被重用
//     // ----------------------------------------------------------------
//     let newEids = entities.spawn(removedCount)
    
//     // 關鍵指標：如果你有 FreeList，新生成的 ID 應該會填補舊的空洞
//     // 所以 Max ID 不應該超過原本的 initialCount (50,000)
//     let maxEid = newEids.max() ?? EntityId(id: -1, version: -1)
    
//     print("🔄 Recycled ID Max Value: \(maxEid.id) (Should be < \(initialCount))")
    
//     // 驗證 ID 回收邏輯 (這是微內核是否 "Leak" 的關鍵)
//     #expect(maxEid.id < initialCount, "ID Recycling Failed! IDs are growing indefinitely.")
    
//     // 把新回收的 ID 加回 Storage，填補記憶體空洞
//     for (index, eid) in newEids.enumerated() {
//         storage.add(eid: eid, component: Position(x: Float(index), y: 100))
//     }

//     // ----------------------------------------------------------------
//     // 4. 效能驗收：在高度碎片化歷史後，進行全量遍歷
//     // ----------------------------------------------------------------
//     let clock = ContinuousClock()
//     let start = clock.now
    
//     var checksum: Float = 0
//     var iterateCount = 0
    
//     // 模擬 System 的遍歷邏輯
//     for i in stride(from: storage.firstActiveSegment, through: storage.lastActiveSegment, by: 1) {
//         // 核心優化：你的架構允許直接跳過 nil 的大區塊 (L1 Skip)
//         let l2 = storage.segments[i]
        
//         // L2 內部遍歷 (SIMD Friendly)
//         for j in 0..<l2.pointee.count {
//             let comp = l2.pointee.components[j]
//             checksum += (comp.x) * (comp.y)
//             iterateCount += 1
//         }
//     }
    
//     let end = clock.now
//     let time = end - start
    
//     print("🚀 Fragmented Traversal Time: \(time)")
//     print("   Processed \(iterateCount) entities. Checksum: \(checksum)")
    
//     // ----------------------------------------------------------------
//     // 5. 最終驗證
//     // ----------------------------------------------------------------
//     // 確保真的有跑完整個迴圈 (防止 Release 模式下被編譯器優化掉)
//     #expect(checksum > 0)
//     #expect(iterateCount == initialCount)
// }