import Testing
@testable import ECScore

@Test func testEntity() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    let e1 = EntityId(id: 1, version: 0)
    #expect(e1.id == 1)
    #expect(e1.version == 0)
    #expect(e1.description == "E(id:1, v:0)")

}

@Test func testStorage() async throws {
    struct TestComponent: Component, Equatable { var test: Int }
    let storage = Storage<TestComponent>(  )
    let e = EntityId(id: 1111, version: 2222)
    
    storage.addEntity(newEntity: e, TestComponent(test: -333))
    
    #expect(storage.contains(e))
    #expect(storage.components[0] == TestComponent(test: -333))

    storage.alterEntity(entity: e) { comp in
        comp.test = 666
    }
    
    #expect(storage.components[0] != TestComponent(test: -333))
    #expect(storage.components[0] == TestComponent(test: 666))
}