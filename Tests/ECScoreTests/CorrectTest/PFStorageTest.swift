import Testing
import Foundation
@testable import ECScore // 請確保替換成你的實際模組名稱

struct MockComponent: Component, Equatable {
    var value: Int
    init() { self.value = 0 }
    init(value: Int) { self.value = value }
}

@Suite("PFStorage 壓力測試")
struct PFStorageStressTests {
    
    @Test("300_000 次隨機增加與刪除測試")
    func stressTestRandomOperations() {
        var storage = PFStorage<MockComponent>()
        
        // 用來比對正確性的影子字典
        var expectedData = [Int: Int]()
        var activeIds = [Int]()
        
        let totalOperations = 300_000
        let maxIdRange: Int = 100_000 // 讓 ID 分散在多個 Segment (100_000 / 4096 ≈ 24 pages)
        
        print("開始執行 \(totalOperations) 次隨機操作...")
        
        for i in 0..<totalOperations {
            // 隨機決定操作：51% 增加, 49% 刪除
            let shouldAdd = activeIds.isEmpty || Int.random(in: 0..<100) < 51            
            if shouldAdd {
                // 隨機生成一個尚未存在的 ID
                var randomId: Int
                repeat {
                    randomId = Int.random(in: 0..<maxIdRange)
                } while expectedData[randomId] != nil
                
                let val = Int(randomId) * 10
                let eid = EntityId(id: randomId, version: 0)
                
                // 執行增加
                storage.add(eid: eid, component: MockComponent(value: val))
                
                // 紀錄狀態
                expectedData[randomId] = val
                activeIds.append(randomId)
                
            } else {
                // 隨機挑選一個已存在的 ID 刪除
                let randomIndex = Int.random(in: 0..<activeIds.count)
                let idToRemove = activeIds.remove(at: randomIndex)
                let eid = EntityId(id: idToRemove, version: 0)
                
                // 執行刪除
                storage.remove(eid: eid)
                
                // 紀錄狀態
                expectedData.removeValue(forKey: idToRemove)
            }
            
            // 每 1000 次操作進行一次快速驗證
            if i % 1000 == 0 {
                #expect(storage.activeEntityCount == expectedData.count)
            }
        }
        
        print("隨機操作完成，開始進行最終完整性驗證...")
        
        // 1. 驗證總數
        #expect(storage.activeEntityCount == expectedData.count)
        
        // 2. 驗證所有應存在的資料
        for (id, expectedVal) in expectedData {
            let eid = EntityId(id: id, version: 0)
            let comp: MockComponent? = storage.get(eid)
            
            #expect(comp != nil, "ID \(id) 應該存在但卻找不到")
            #expect(comp?.value == expectedVal, "ID \(id) 的值錯誤，預期 \(expectedVal) 但拿到 \(comp?.value ?? -1)")
        }
        
        // 3. 隨機驗證一些不該存在的 ID
        for _ in 0..<1000 {
            let randomId = Int.random(in: 0..<maxIdRange)
            if expectedData[randomId] == nil {
                let eid = EntityId(id: randomId, version: 0)
                let comp: MockComponent? = storage.get(eid)
                #expect(comp == nil, "ID \(randomId) 應該已刪除但卻還能讀取到資料")
            }
        }
        
        print("測試通過！當前活躍實體數: \(storage.activeEntityCount), 使用 Segment 數: \(storage.activeSegmentCount)")
    }
}