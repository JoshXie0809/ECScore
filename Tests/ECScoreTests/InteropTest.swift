import Testing
@testable import ECScore // 替換為你的模組名稱

// 模擬組件 A
struct MockComponentA: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<MockComponentA>()
    }
}

// 模擬組件 B
struct MockComponentB: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<MockComponentB>()
    }
}

@Suite("BasePlatform Interop 測試")
struct PlatformTests {
    
    // 輔助方法：快速初始化一個已 Boot 的平台
    private func makeBootedPlatform() -> (BasePlatform, RegistryPlatform) {
        let base = BasePlatform()
        let registry = RegistryPlatform()
        let entities = EntitiyPlatForm_Ver0()
        
        // 建立初始環境：Registry(0), Entities(1)
        base.boot(registry: registry, entities: entities)
        return (base, registry)
    }

    @Test("驗證 Interop 能正確註冊新組件並分配 Storage")
    func testInteropRegistration() {
        let (base, registry) = makeBootedPlatform()
        
        // 1. 準備 Manifest
        let componentA = MockComponentA()
        let manifest = Manifest(requirements: [
            .Public_Component((MockComponentA.self, componentA))
        ])

        // 2. 執行 Interop
        let tokens = base.interop(manifest: manifest)

        // 3. 斷言驗證
        let ridA = registry.register(MockComponentA.self)
        
        // 驗證 ID 是否被正確分配
        #expect(tokens.rids.contains(ridA))
        
        // 驗證 Storage 陣列是否已擴張並填入
        #expect(base.storages.count > ridA.id)
        #expect(base.rawGetStorage(for: ridA) != nil)
    }

    @Test("驗證多個組件同時註冊時的 Storage 容量與順序")
    func testMultipleComponents() {
        let (base, registry) = makeBootedPlatform()
        
        let manifest = Manifest(requirements: [
            .Public_Component((MockComponentA.self, MockComponentA())),
            .Private_Component((MockComponentB.self, MockComponentB()))
        ])

        _ = base.interop(manifest: manifest)

        let ridA = registry.register(MockComponentA.self)
        let ridB = registry.register(MockComponentB.self)

        // 驗證 Registry 確實包含這些型別
        #expect(registry.contains(MockComponentA.self))
        #expect(registry.contains(MockComponentB.self))

        // 驗證所有的 Storage 都已正確初始化
        #expect(base.rawGetStorage(for: ridA) != nil)
        #expect(base.rawGetStorage(for: ridB) != nil)
        
        // 驗證 storages 長度與 Registry 計數同步
        #expect(base.storages.count == registry.count)
    }
}

// 模擬組件 C
struct MockComponentC: Component {
    let value: String
    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<MockComponentC>()
    }
}

@Test("驗證從 Interop 到 Build 的完整流程：實體應包含正確的組件資料")
func testFullBuildProcess() {
    let base = BasePlatform()
    let registry = RegistryPlatform()
    let entities = EntitiyPlatForm_Ver0()
    base.boot(registry: registry, entities: entities)

    // 1. 定義初始資料
    let expectedValue = "Hello ECS"
    let mockComponent = MockComponentC(value: expectedValue) // 假設 MockComponentA 有這個 property
    let manifest = Manifest(requirements: [
        .Public_Component((MockComponentC.self, mockComponent))
    ])

    // 2. 執行 Interop (準備環境)
    let tokens = base.interop(manifest: manifest)

    // 3. 執行 Build (產生實體)
    let eid = base.build(from: tokens).eid

    // 4. 驗證資料是否正確進入 Storage
    let rid = registry.register(MockComponentC.self)
    let storage = base.rawGetStorage(for: rid)
    
    #expect(storage != nil)

    // 假設 PFStorage 有一個根據 eid 取得組件的方法
    if let savedComponent = storage?.get(eid) as? MockComponentC {
        #expect(savedComponent.value == expectedValue)
    } else {
        Issue.record("組件未正確存入 Storage")
    }
}