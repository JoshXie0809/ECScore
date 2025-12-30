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



@Test func testQuery() async throws {
    struct Comp1: Component {}
    struct Comp2: Component {}
    
    let w = World()

    w.addStorage(Storage<Comp1>())
    w.addStorage(Storage<Comp2>())
    let s1 = w[Comp1.self]
    let s2 = w[Comp2.self]

    for _ in 0..<200 {
        let e = w.createEntity()
        s1.addEntity(newEntity: e, Comp1())
    } 

    for _ in 0..<100 {
        let e = w.createEntity()
        s1.addEntity(newEntity: e, Comp1())
        s2.addEntity(newEntity: e, Comp2())
    } 

    for _ in 0..<100 {
        let e = w.createEntity()
        s2.addEntity(newEntity: e, Comp2())
    }
    
}

@Test func testQuery2() async throws {
    struct Comp1: Component {}
    struct Comp2: Component {}
    struct Comp3: Component {}
    struct Comp4: Component {}

    let w = World()
    let s1 = w[Comp1.self]
    _ = w[Comp2.self]
    _ = w[Comp3.self]
    let s2 = w[Comp4.self]

    s1.addEntity(newEntity: w.createEntity(), Comp1())
    s1.addEntity(newEntity: w.createEntity(), Comp1())
    s1.addEntity(newEntity: w.createEntity(), Comp1())
    s1.addEntity(newEntity: w.createEntity(), Comp1())
    s1.addEntity(newEntity: w.createEntity(), Comp1())

    s2.addEntity(newEntity: w.createEntity(), Comp4())
    s2.addEntity(newEntity: w.createEntity(), Comp4())

    let query = w.queryDraft()
        .with(Comp1.self)
        .with(Comp4.self)
        .without(Comp2.self)
        .without(Comp3.self)
        .buildQuery()

    let ws1 = query.with[0]
    let ws2 = query.with[1]

    #expect(ws1 == ObjectIdentifier(Comp4.self))
    #expect(ws2 == ObjectIdentifier(Comp1.self))
}