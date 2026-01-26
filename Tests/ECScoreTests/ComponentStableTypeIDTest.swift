import Testing
@testable import ECScore

struct TypeStringTest_Special: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        PFStorageBox(PFStorageHandle<Self>())
    }

    static let typeIdString: String = "hello world"
    static let _hs: TypeStrIdHashed_FNV1A_64 = #hs_fnv1a64("hello world")
}

struct TypeStringTest_Default: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        PFStorageBox(PFStorageHandle<Self>())
    }
}

@Suite("TypeHashedStringTest")
struct TypeHashedStringTest {    
    @Test func defalutTypeStringTest() async throws {
        let type = TypeStringTest_Special.self
        #expect(type.typeIdString == "hello world")
        
        
        let type2 = TypeStringTest_Default.self
        #expect(type2.typeIdString == "ECScoreTests.TypeStringTest_Default")
        
    }

    @Test func hashStringTest() async throws {
        let type = TypeStringTest_Special.self
        #expect(type._hs == #hs_fnv1a64("hello world"))
    }

    @Test func registryUniquenessTest() {
        let registry = RegistryPlatform()
        
        let rid1 = registry.register(TypeStringTest_Special.self)
        let rid2 = registry.register(TypeStringTest_Default.self)
        
        // 確保不同的組件拿到不同的 ID
        #expect(rid1 != rid2)
        
        // 確保多次註冊同一個組件拿到同一個 ID
        let rid1_again = registry.register(TypeStringTest_Special.self)
        #expect(rid1 == rid1_again)
    }

    @Test func registryReverseLookupTest() {
        let registry = RegistryPlatform()
        let rid = registry.register(TypeStringTest_Default.self)
        
        // 驗證反向查詢
        let type = registry.lookup(rid)
        #expect(type == TypeStringTest_Default.self)
    }

}
