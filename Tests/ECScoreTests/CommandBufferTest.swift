import Testing
@testable import ECScore

struct MovedTag: TagComponent {}

@Test func CommandBufferTest() async throws {
    let base = makeBootedPlatform()
    let mvToken = interop(base, MovedTag.self)
    let pToken = interop(base, Position.self)
    let n = 16_888

    let clock = ContinuousClock()

    emplace(base, tokens: pToken) {
        entities, pack in
        var pSt = pack.storages

        for i in 1...n {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: Float(i), y: Float(i + 1)))
        }
    }

    var cmdbf = mvToken.getCommandBuffer(base: base)

    let s0 = clock.now
    view(base: base, with: pToken) {
        iterId, pos in
        if (iterId.eidId % 2 == 0) { 

            // update
            pos.fast.x += 1 
            // add moved tag
            cmdbf.addCommand(iterId)
            cmdbf.addCommand(iterId) // idempotent

        }
    }
    print(clock.now - s0)


    let s1 = clock.now
    // observer system use tag to get entity
    var count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        // let d = (pos.fast.x - pos.fast.y)
        // #expect(d == 0.0)
        count += 1
    }
    
    #expect(count == (n / 2))
    cmdbf.removeAll()
    cmdbf.removeAll() // idempotent

    print(clock.now - s1)


    let s2 = clock.now
    count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        count += 1
    }

    #expect(count == 0)
    print(clock.now - s2)

    // next frame

    view(base: base, with: pToken) {
        iterId, pos in
        if (iterId.eidId % 2 == 0) { 

            // update
            pos.fast.x += 1 
            // add moved tag
            cmdbf.addCommand(iterId)
        }
    }

    let s3 = clock.now
    // observer system use tag to get entity
    count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        let d = (pos.fast.x - pos.fast.y)
        #expect(d == 1.0)
        count += 1
    }

    #expect(count == (n / 2))
    
    cmdbf.removeAll()
    cmdbf.removeAll() // idempotent
    print(clock.now - s3)

    let s4 = clock.now
    count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        count += 1
    }

    #expect(count == 0)
    print(clock.now - s4)
}


@Test func DynamicRandomUpdateWithCountTest() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let mvToken = interop(base, MovedTag.self)
    
    let totalEntities = 1_000_000
    var rng = Xoshiro128(seed: 999)

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        var rmList = [EmplaceEntityId]()
        rmList.reserveCapacity(600_000)

        for _ in 0..<totalEntities {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: 0, y: 0))
            let roll = rng.next() & 1
            if roll == 0 { rmList.append(eid) }
        }

        for eeid in rmList {
            entities.destroyEntity(eeid)
        }
    }
    
    
    var cmdbf = mvToken.getCommandBuffer(base: base)

    var posSt = pToken.getStorage(base: base)
    var rmList = [Int]()
    rmList.reserveCapacity(2_000)
    
    // --- 第一階段：隨機更新並計數 ---
    var expectedCount = 0 
    view(base: base, with: pToken) { iterId, pos in
        // 模擬 0.1% 的機率
        if (rng.next() & 1023 == 0) { 
            expectedCount += 1
            pos.fast.x += 1.0
            cmdbf.addCommand(iterId)
            let roll = rng.next() & 1
            if roll == 0 {
                rmList.append(iterId.eidId)
                expectedCount -= 1
            }
        }
    }

    for i in rmList {
        posSt.remove(eid: EntityId(id: i, version: -1)) // 我目前還沒有支持 用 Eid-id 刪除的 api 只能用最初寫好的 Eid 路徑
    }
    
    print("Expected moved entities: \(expectedCount)")

    // --- 第二階段：驗證過濾數量 ---
    var actualCount = 0
    view(base: base, with: pToken, withTag: mvToken) { iterId, pos in
        actualCount += 1
        #expect(pos.fast.x == 1.0) // 確保數據真的有改到
    }
    
    print("Actual moved entities found by tag: \(actualCount)")
    
    // 核心驗證：標籤過濾出的數量必須等於隨機觸發的次數
    #expect(actualCount == expectedCount)
    
    // --- 第三階段：清理並驗證歸零 ---
    cmdbf.removeAll()
    
    var finalCount = 0
    view(base: base, with: (), withTag: mvToken) { _ in finalCount += 1 }
    #expect(finalCount == 0)
}

struct TargetTag: TagComponent {}
struct ProcessedTag: TagComponent {}

@Test func ChainReactionSystemTest() async throws {
    let base = makeBootedPlatform()
    
    // 1. 註冊組件與標籤
    let pToken = interop(base, Position.self)
    let targetTag = interop(base, TargetTag.self) // 假設你定義了這個 Tag
    let processedTag = interop(base, ProcessedTag.self) // 假設你定義了這個 Tag
    
    let total = 880_000
    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for i in 0..<total {
            let eid = entities.createEntity()
            // 一半在左(x=-1)，一半在右(x=1)
            let posX = i < total / 2 ? -1.0 : 1.0
            pSt.addComponent(eid, Position(x: Float(posX), y: 0))
        }
    }

    // --- System A: 標記階段 ---
    // 取得 TargetTag 的 Buffer
    var targetBuffer = targetTag.getCommandBuffer(base: base)
    view(base: base, with: pToken) { iterId, pos in
        if pos.fast.x > 0 {
            targetBuffer.addCommand(iterId)
        }
    }
    // 模擬幀末或系統間的 Flush (如果你的架構需要)
    // base.flushCommands() 

    // --- System B: 轉換階段 ---
    var procBuffer = processedTag.getCommandBuffer(base: base)
    var targetRemover = targetTag.getCommandBuffer(base: base)
    
    var processedCount = 0
    // 這裡同時要求 Position 和 TargetTag
    view(base: base, with: pToken, withTag: targetTag) { iterId, pos in
        pos.fast.x *= 2.0
        targetRemover.removeCommand(iterId) // 移除舊標籤
        procBuffer.addCommand(iterId)       // 加上新標籤
        processedCount += 1
    }

    // --- System C: 最終驗證 ---
    var finalCheckCount = 0
    view(base: base, with: (), withTag: processedTag) { _ in
        finalCheckCount += 1
    }
    
    print("System B processed: \(processedCount)")
    print("System C verified: \(finalCheckCount)")

    #expect(processedCount == total / 2)
    #expect(finalCheckCount == total / 2)
    
    // 驗證 TargetTag 是否真的被清空了
    var leftoverTags = 0
    view(base: base, with: (), withTag: targetTag) { _ in leftoverTags += 1 }
    #expect(leftoverTags == 0)
}

@Test func ChainReactionSystemTest_IdempotentStress() async throws {
    let base = makeBootedPlatform()
    
    let pToken = interop(base, Position.self)
    let targetTag = interop(base, TargetTag.self)
    let processedTag = interop(base, ProcessedTag.self)
    
    let total = 880_000
    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for i in 0..<total {
            let eid = entities.createEntity()
            let posX = i < total / 2 ? -1.0 : 1.0
            pSt.addComponent(eid, Position(x: Float(posX), y: 0))
        }
    }

    // --- System A: 瘋狂標記階段 ---
    var targetBuffer = targetTag.getCommandBuffer(base: base)
    view(base: base, with: pToken) { iterId, pos in
        if pos.fast.x > 0 {
            // 【故意刁難 1】：同一個實體標記 5 次
            // 在傳統 Array 框架中，這會產生 220 萬個指令 (44萬 * 5)
            targetBuffer.addCommand(iterId)
            targetBuffer.addCommand(iterId)
            targetBuffer.addCommand(iterId)
            targetBuffer.addCommand(iterId)
            targetBuffer.addCommand(iterId)
        }
    }

    // --- System B: 瘋狂轉換階段 ---
    var procBuffer = processedTag.getCommandBuffer(base: base)
    var targetRemover = targetTag.getCommandBuffer(base: base)
    
    var processedCount = 0
    view(base: base, with: pToken, withTag: targetTag) { iterId, pos in
        pos.fast.x *= 2.0
        
        // 【故意刁難 2】：重複移除標籤
        targetRemover.removeCommand(iterId)
        targetRemover.removeCommand(iterId)
        
        // 【故意刁難 3】：重複添加處理標籤
        procBuffer.addCommand(iterId)
        procBuffer.addCommand(iterId)
        procBuffer.addCommand(iterId)
        
        processedCount += 1
    }

    // --- System C: 最終驗證 ---
    var finalCheckCount = 0
    view(base: base, with: (), withTag: processedTag) { _ in
        finalCheckCount += 1
    }
    
    print("System B processed: \(processedCount)")
    print("System C verified: \(finalCheckCount)")

    #expect(processedCount == total / 2)
    #expect(finalCheckCount == total / 2)
    
    var leftoverTags = 0
    view(base: base, with: (), withTag: targetTag) { _ in leftoverTags += 1 }
    #expect(leftoverTags == 0)
}

@Test func PhysicalReactiveSystemTest() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let targetTag = interop(base, TargetTag.self)

    var targetBuffer = targetTag.getCommandBuffer(base: base)
    
    // 1. 初始化 10 萬個帶有標籤的實體
    let total = 100_000
    emplace(base, tokens: pToken) { entities, pack in
        var st = pack.storages

        for _ in 0..<total {
            let eid = entities.createEntity()
            st.addComponent(eid, Position(x: 1.0, y: 0))
            targetBuffer.addCommand(eid) 
        }
    }
    
    // --- 階段 A：邏輯處理，移除一半的標籤 ---
    var remover = targetTag.getCommandBuffer(base: base)
    var count = 0

    view(base: base, with: (), withTag: targetTag) { iterId in
        if count % 2 == 0 {
            remover.removeCommand(iterId) // 這裡只是移除標籤
        }
        count += 1
    }

    // --- 階段 B：物理觸發（Reactive Cleanup） ---
    // 這就是「自動觸發」：我們找那些「有 Position 但沒 TargetTag」的孤兒
    var posRemover = pToken.getCommandBuffer(base: base)
    var reactiveCount = 0
    
    // 關鍵在於這個 `withoutTag` 的過濾邏輯
    view(base: base, with: pToken, withoutTag: targetTag) { iterId, pos in
        posRemover.removeCommand(iterId) // 自動清理組件
        reactiveCount += 1
    }

    print("Automatically reacted and cleaned: \(reactiveCount)")
    #expect(reactiveCount == 50_000)
    
    // --- 驗證最後結果 ---
    var finalCount = 0
    view(base: base, with: pToken) { _, _ in finalCount += 1 }
    #expect(finalCount == 50_000)
}
