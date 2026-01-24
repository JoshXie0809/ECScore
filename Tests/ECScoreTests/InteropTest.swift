import Testing
@testable import ECScore 


// 模擬組件 A
struct MockComponentA: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }
}

// 模擬組件 B
struct MockComponentB: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }
}

@Suite("BasePlatform Interop 測試")
struct PlatformTests {
    // 輔助方法：快速初始化一個已 Boot 的平台
    private func makeBootedPlatform() -> Validated<BasePlatform, Proof_Handshake, Platform_Facts> {
        let base = BasePlatform()
        let registry = RegistryPlatform()
        let entities = EntityPlatForm_Ver0()
        
        // 建立初始環境：Registry(0), Entities(1)
        base.boot(registry: registry, entities: entities)

        var pf_val = Raw(value: base).upgrade(Platform_Facts.self)
        validate(validated: &pf_val, Platform_Facts.FlagCase.handshake.rawValue)

        // 被驗證可以 handshake 的平台
        guard case let .success(pf_handshake) = pf_val.certify(Proof_Handshake.self) else {
            fatalError()
        }

        return pf_handshake
    }

    @Test("驗證 Interop 使用 Validated<T, P, F>")
    func testInterop() {
        let base = makeBootedPlatform()
        let before_interop = base.value.storages.count

        // 未驗證的 input
        let manifest: ComponentManifest = [MockComponentA.self, MockComponentB.self, PFStorageBox<Position>.self]
        // 驗證流程
        var manifest_val = Raw(value: manifest).upgrade(Manifest_Facts.self)
        let ok = validate(validated: &manifest_val, Manifest_Facts.FlagCase.unique.rawValue)
        #expect(ok)
        guard case let .success(manifest_unique) = manifest_val.certify(Proof_Unique.self) else {
            fatalError()
        }
        
        // // 執行 Interop
        interop(base, manifest_unique)
        #expect(base.value.storages.count - before_interop == 3)
    }

    @Test("static version of interop")
    func static_interop() {
        let base = makeBootedPlatform()

        let token = interop(base, 
            MockComponentA.self, MockComponentB.self, 
            Position.self, PFStorageBox<Position>.self, PFStorageBox<PFStorageBox<Position>>.self
        )
        print(token)
        typealias R = PFStorageBox<PFStorageBox<Position>>

        print(R.createPFStorage())
    }

    @Test("test Validated Platform to spawn entities")
    func testSpawn() throws {
        let base = makeBootedPlatform()
        let fn1 =  { EntityPlatForm_Ver0() }
        let fn2 = { Position(x: 1.2, y: 22.3) }
        let fn3 = { MockComponentA() }
        let fn4 = { MockComponentB() }

        let eids = spawnEntity(base, 3)
        let eh = try base.getEntityHandle(eids[2]).get()
        
        var mounter = Mounter(base.clone(), eh)
        let cache: MounterCache = mounter.mountAndCache(fn1, fn2, fn3, fn4)

        let e_pf_rid = base.registry.register(EntityPlatForm_Ver0.self)
        let postion_rid = base.registry.register(Position.self)

        #expect(base.storages[e_pf_rid.id]!.get(eids[2]) != nil)
        #expect(base.storages[postion_rid.id]!.get(eids[2]) != nil)

        var a = base.storages[postion_rid.id]!.get(eids[2]) as! Position
        #expect(a.x == 1.2)
        #expect(a.y == 22.3)

        // get new eid
        let eh2 = try base.getEntityHandle(eids[1]).get()
        // replace mounter eid and mount using cache
        mounter = mounter.replaceEntityHandle(eh2).mountWithCached(cache)

        #expect(base.storages[e_pf_rid.id]!.get(eids[1]) != nil)
        #expect(base.storages[postion_rid.id]!.get(eids[1]) != nil)

        a = base.storages[postion_rid.id]!.get(eids[1]) as! Position
        #expect(a.x == 1.2)
        #expect(a.y == 22.3)


        // get new eid
        let eh3 = try base.getEntityHandle(eids[0]).get()
        // replace mounter eid and mount using cache
        mounter = mounter.replaceEntityHandle(eh3).mountWithValuesWithCached(
            cache.token,
            EntityPlatForm_Ver0(),
            Position(x: -12345.0, y: 0.0),
            MockComponentA(),
            MockComponentB()
        )

        #expect(base.storages[e_pf_rid.id]!.get(eids[0]) != nil)
        #expect(base.storages[postion_rid.id]!.get(eids[0]) != nil)

        a = base.storages[postion_rid.id]!.get(eids[0]) as! Position
        #expect(a.x == -12345.0)
        #expect(a.y == 0.0)
    }
}


// @Suite("BasePlatform Interop 測試")
// struct PlatformTests {

//     @Test("驗證多個組件同時註冊時的 Storage 容量與順序")
//     func testMultipleComponents() {
//         let (base, registry) = makeBootedPlatform()
        
//         let fnA = { return MockComponentA() }
//         let fnB = { return MockComponentB() }
        
//         let manifest = Manifest(requirements: [
//             .Public_Component((MockComponentA.self, fnA )),
//             .Private_Component((MockComponentB.self, fnB ))
//         ])

//         _ = base.interop(manifest: manifest)

//         let ridA = registry.register(MockComponentA.self)
//         let ridB = registry.register(MockComponentB.self)

//         // 驗證 Registry 確實包含這些型別
//         #expect(registry.contains(MockComponentA.self))
//         #expect(registry.contains(MockComponentB.self))

//         // 驗證所有的 Storage 都已正確初始化
//         #expect(base.rawGetStorage(for: ridA) != nil)
//         #expect(base.rawGetStorage(for: ridB) != nil)
        
//         // 驗證 storages 長度與 Registry 計數同步
//         #expect(base.storages.count == registry.count)
//     }
// }

// // 模擬組件 C
// struct MockComponentC: Component {
//     let value: String
//     static func createPFStorage() -> any AnyPlatformStorage {
//         return PFStorage<MockComponentC>()
//     }
// }

// @Test("驗證從 Interop 到 Build 的完整流程：實體應包含正確的組件資料")
// func testFullBuildProcess() {
//     let base = BasePlatform()
//     let registry = RegistryPlatform()
//     let entities = EntityPlatForm_Ver0()
//     base.boot(registry: registry, entities: entities)

//     // 1. 定義初始資料
//     let expectedValue = "Hello ECS"
//     let fnC = {
//         return MockComponentC(value: expectedValue) // 假設 MockComponentA 有這個 property
//     }

//     let manifest = Manifest(requirements: [
//         .Public_Component((MockComponentC.self, fnC))
//     ])

//     // 2. 執行 Interop (準備環境)
//     let tokens = base.interop(manifest: manifest)

//     // 3. 執行 Build (產生實體)
//     let idcard = base.build(from: tokens)
//     print(idcard)
    
//     let eid = idcard.eid

//     // 4. 驗證資料是否正確進入 Storage
//     let rid = registry.register(MockComponentC.self)
//     let storage = base.rawGetStorage(for: rid)
    
//     #expect(storage != nil)

//     // 假設 PFStorage 有一個根據 eid 取得組件的方法
//     if let savedComponent = storage?.get(eid) as? MockComponentC {
//         #expect(savedComponent.value == expectedValue)
//     } else {
//         Issue.record("組件未正確存入 Storage")
//     }
// }


// // @Test func testBatchGeneration() {
// //     // 2. 初始化平台環境 (確保 ID 統一)
// //     let e_pf = EntitiyPlatForm_Ver0()
// //     let r_pf = RegistryPlatform() // 讓 Registry 共用實體管理器
// //     let base = BasePlatform()
// //     base.boot(registry: r_pf, entities: e_pf)

// //     // 3. 準備 Manifest (這就是你的「藍圖」)
// //     // 注意：這裡傳入的是閉包 { MockComponentA() }，確保每次呼叫都會產生新實例
// //     let manifest = Manifest(requirements: [
// //         .Public_Component((MockComponentA.self, { MockComponentA() })),
// //         .Public_Component((MockComponentB.self, { MockComponentB() }))
// //     ])

// //     // 4. Interop (開模) - 這步只做一次！
// //     // 平台會在此時註冊型別並分配好 Storage 空間
// //     let buildTokens = base.interop(manifest: manifest)

// //     print("🚀 開始批次生成 20 個實體...")

// //     var generatedCards: [IDCard] = []

// //     // 5. 批次生成迴圈
// //     for i in 0..<20 {
// //         // 使用同一組 tokens 進行快速生產
// //         let card = base.build(from: buildTokens)
// //         generatedCards.append(card)
        
// //         // (選用) 驗證一下生成結果
// //         // print("  - Generated Entity ID: \(card.eid.id)")
// //     }

// //     print("✅ 生成完畢，共 \(generatedCards.count) 個實體。")
    
// //     // 6. 使用 Inspector 驗證結果
// //     // 你會看到 ID 從 3 開始 (0=Registry, 1=EntityPF, 2=CompA, 3=CompB... 之後才是實體)
// //     // 或是取決於你的註冊順序
// //     base.inspectWorld()
// // }