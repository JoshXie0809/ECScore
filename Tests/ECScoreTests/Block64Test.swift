import Testing
import Foundation
@testable import ECScore

@Test func b64_test1() async throws {
    var sparse = Block64_L2()
    let ssEntry = SparseSetEntry(compArrIdx: 321)

    let offset = 3095
    sparse.addEntityOnBlock(3095, ssEntry: ssEntry)
    let pageIdx = offset >> 6
    let slotIdx = offset & 0x003F

    // mask test
    let bit = UInt64(1) << pageIdx
    #expect(sparse.blockMask & bit != 0)
    let pageBit = UInt64(1) << slotIdx
    #expect(sparse.pageOnBlock[pageIdx].pageMask & pageBit != 0)
    #expect(sparse.contains(offset))
    #expect(sparse.getUnchecked(offset).compArrIdx == 321)
    #expect(sparse.activePageCount == 1)
    #expect(sparse.activeEntityCount == 1)

    // remove test
    sparse.removeEntityOnBlock(offset)
    // mask test
    #expect(sparse.blockMask & bit == 0)
    #expect(sparse.pageOnBlock[pageIdx].pageMask & pageBit == 0)
    #expect(!sparse.contains(offset))
    #expect(sparse.activePageCount == 0)
    #expect(sparse.activeEntityCount == 0)


    // alter test
    sparse.addEntityOnBlock(3092, ssEntry: ssEntry)
    sparse.addEntityOnBlock(30, ssEntry: ssEntry)

    #expect(sparse.activePageCount == 2)
    #expect(sparse.activeEntityCount == 2)
    #expect(sparse.getUnchecked(3092).compArrIdx == 321)

    sparse.updateComponentArrayIdx(3092) { ssEntry in
        ssEntry.compArrIdx = 12
    }

    #expect(sparse.getUnchecked(3092).compArrIdx == 12)
    
}

@Suite("SparseSet_L2 組件倉庫測試")
struct SparseSetL2Tests {
    @Test("驗證 Swap and Pop 邏輯")
    func swapAndPopValidation() async throws {
        var storage = SparseSet_L2<Position>()
        
        let eidA = EntityId(id: 10, version: 1)
        let eidB = EntityId(id: 20, version: 1)
        let eidC = EntityId(id: 30, version: 1)
        
        // 按順序新增 A(10), B(20), C(30)
        storage.add(eidA, Position(x: 1, y: 1)) // Index 0
        storage.add(eidB, Position(x: 2, y: 2)) // Index 1
        storage.add(eidC, Position(x: 3, y: 3)) // Index 2
        
        #expect(storage.count == 3)
        
        // 移除中間的 B (id: 20, index: 1)
        storage.remove(eidB)
        
        // 驗證：B 消失了，總數變 2
        #expect(storage.count == 2)
        #expect(storage.get(offset: 20) == nil)
        
        // 驗證核心 Swap & Pop：原本最後一個 C (3,3) 應該被搬到了索引 1 (原 B 的位置)
        // 1. 數據內容搬移
        #expect(storage.getWithDenseIndex_Uncheck(denseIdx: 1).x == 3)
        // 2. 稀疏索引同步更新：id 30 映射到的 DenseIndex 應該變成 1
        let entryC = storage.sparse.getUnchecked(30)
        #expect(entryC.compArrIdx == 1)
        // 3. 反向表更新：Index 1 對應的 Offset 應該是 30
        #expect(storage.reverseEntities[1].offset == 30)
    }
    
    @Test("驗證數據更新功能")
    func updateInPlace() async throws {
        var storage = SparseSet_L2<Position>()
        let eid = EntityId(id: 5, version: 1)
        storage.add(eid, Position(x: 10, y: 10))
        
        // 測試 In-place 修改
        storage.updateWithDenseIndex_Uncheck(denseIdx: 0) { pos in
            pos.x = 99
        }
        
        #expect(storage.get(offset: 5)?.x == 99)
    }
}


@Suite("Block64_L2 底層測試")
struct Block64Tests {
    @Test("驗證位圖索引與分頁生命週期")
    func bitmapAndPageLifecycle() async throws {
        var sparse = Block64_L2()
        let entry = SparseSetEntry(compArrIdx: 123)
        let offset = 3095 // 在第 48 頁 (3095 / 64)
        
        // 1. 新增
        sparse.addEntityOnBlock(offset, ssEntry: entry)
        #expect(sparse.contains(offset))
        #expect(sparse.activeEntityCount == 1)
        #expect(sparse.activePageCount == 1)
        #expect(sparse.getUnchecked(offset).compArrIdx == 123)
        
        // 2. 測試位元遮罩 (BlockMask)
        let pageIdx = offset >> 6
        let bit = UInt64(1) << pageIdx
        #expect(sparse.blockMask & bit != 0)
        
        // 3. 移除並驗證自動釋放 Page
        sparse.removeEntityOnBlock(offset)
        #expect(!sparse.contains(offset))
        #expect(sparse.activeEntityCount == 0)
        #expect(sparse.activePageCount == 0) // 因為最後一個實體沒了，Page 也該被釋放
        #expect(sparse.blockMask == 0)
    }
}


@Suite("PFStorage 動態分頁測試")
struct PFStorageTests {
    @Test("大跨度 ID 導致的 Segments 擴增與回收")
    func segmentExpansionAndRecycle() async throws {
        var storage = PFStorage<Position>()
        
        // 1. 新增一個 ID 非常大的實體 (跨 Block)
        let bigId = 5000 // 5000 >> 12 = 1, 會落入第 2 個 segment (index 1)
        let eidBig = EntityId(id: bigId, version: 1)
        
        storage.add(eid: eidBig, component: Position(x: 50, y: 50))
        
        // 驗證：segments 長度應該變為 2 (index 0, index 1)
        #expect(storage.segments.count == 2)
        #expect(storage.segments[1] != nil)
        #expect(storage.segments[0] != nil) // 初始化會預留第一個
        
        // 2. 移除該實體
        storage.remove(eid: eidBig)
        
        // 驗證選配優化：當 L2 完全空了，segment 應該被設回 nil 以釋放內存
        #expect(storage.segments[1] == nil)
    }
    
    @Test("大量數據分頁壓力測試", arguments: [0, 4095, 4096, 8191, 8192])
    func boundaryTests(id: Int) async throws {
        var storage = PFStorage<Position>()
        let eid = EntityId(id: id, version: 1)
        
        storage.add(eid: eid, component: Position(x: 0, y: 0))
        #expect(storage.segments[id >> 12] != nil)
        #expect(storage.segments[id >> 12]!.sparse.contains(id & 0x0FFF))
    }
}


@Test("強制執行 Swap 補位邏輯以覆蓋程式碼")
func testForceSwapLogic() async throws {
    var storage = SparseSet_L2<Position>()
    let eid1 = EntityId(id: 1, version: 1)
    let eid2 = EntityId(id: 2, version: 1)
    
    // 1. 新增兩個實體：A 在索引 0, B 在索引 1
    storage.add(eid1, Position(x: 1, y: 1)) 
    storage.add(eid2, Position(x: 2, y: 2)) 
    
    // 2. 刪除第一個實體 (eid1)
    // 此時 removeIdx = 0, lastIdx = 1 (因為刪除前 count 是 2)
    // 0 < 1 成立，這會強制執行你截圖中那段 if 區塊！
    storage.remove(eid1)
    
    // 3. 驗證補位是否成功
    #expect(storage.count == 1)
    #expect(storage.getWithDenseIndex_Uncheck(denseIdx: 0).x == 2) // B 應該搬到了索引 0
}


@Test func testSwapAndPopEfficiency() async throws {
    var storage = PFStorage<Position>()
    let entities = Entities()
    
    // 1. 產生三個實體
    let eids = entities.spawn(3)
    let e1 = eids[0], e2 = eids[1], e3 = eids[2]
    
    // 2. 依序新增組件 (DenseIndex: 0, 1, 2)
    storage.add(eid: e1, component: Position(x: 1, y: 1))
    storage.add(eid: e2, component: Position(x: 2, y: 2))
    storage.add(eid: e3, component: Position(x: 3, y: 3))
    
    // 3. 刪除中間的 e2 (DenseIndex: 1)
    // 這會觸發 image_74540c.png 第 47 行：removeIdx(1) < lastIdx(2)
    storage.remove(eid: e2)
    
    // 4. 驗證補位邏輯
    // 原本最後一個 e3 應該被搬移到索引 1 的位置
    let movedComponent = storage.getWithDenseIndex_Uncheck(1) as? Position
    #expect(movedComponent?.x == 3) // 確認數據搬過來了
    
    // 5. 驗證總數與結構
    // 剩下的應該只有 2 個，且 e2 徹底消失
    #expect(storage.getWithDenseIndex_Uncheck(2) == nil)
}


@Test func testLargeScalePerformance() async throws {
    var storage = PFStorage<Position>()
    let entities = Entities()
    let count = 50000
    let eids = entities.spawn(count)
    
    // 1. 批次寫入測試
    for i in 0..<count {
        storage.add(eid: eids[i], component: Position(x: Float(i), y: 0))
    }
    
    // 2. 測量全量遍歷耗時
    let start = DispatchTime.now()
    
    var sum: Float = 0
    // 使用你最快的「非 nil segment 遍歷」邏輯
    for segment in storage.segments {
        guard let l2 = segment else { continue }
        for i in 0..<l2.count {
            sum += l2.components[i].x
        }
    }
    
    let end = DispatchTime.now()
    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000
    
    print("50,000 entities traversal time: \(timeInterval) ms")
    
    // 驗證計算結果正確
    #expect(sum > 0)
}
