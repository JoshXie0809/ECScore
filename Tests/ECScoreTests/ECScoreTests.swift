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

    let e2 = EntityId(id: 1115, version: 2222)
    let e3 = EntityId(id: 11167, version: 2222)
    storage.addEntity(newEntity: e2, TestComponent(test: 666))
    storage.addEntity(newEntity: e3, TestComponent(test: 777))

    storage.removeEntity(e)
    #expect(!storage.contains(e))
    #expect(storage.count == 2)
    #expect(storage.activeEntities[0] == e3)
    #expect(storage.activeEntities[1] == e2)
}

@Test func testWorld() async throws {
    let w = World()

    let entity = w.createEntity()
    #expect(w.contains(entity))
    let invalidEntity = EntityId(id: 100, version: 203)
    #expect(!w.contains(invalidEntity))

    w.destroyEntity(entity)
    #expect(w.entityCount == 0)

    let entitiy2 = w.createEntity()
    #expect(entitiy2.version == 1)

    struct TestComponent: Component {}
    let storage = Storage<TestComponent>()
    w.addStorage(storage)

    storage.addEntity(newEntity: entitiy2, TestComponent())

    let storageRef = w[TestComponent.self]
    #expect(storageRef === storage)

    w.destroyStorage(TestComponent.self)
    #expect(w.storageCount == 0)
} 