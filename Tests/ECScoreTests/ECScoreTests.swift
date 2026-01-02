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
    #expect(storage.entities[0] == e3)
    #expect(storage.entities[1] == e2)
}

@Test func testWorld() async throws {
    let w = World()

    let entity = w.createEntity()
    #expect(w.contains(entity))
    let invalidEntity = EntityId(id: 100, version: 203)
    #expect(!w.contains(invalidEntity))

    _ = w.destroyEntity(entity)
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


struct Comp1: Component {}
struct Comp2: Component {}

@Test func testQuery() async throws {
    let w = World()

    w.addStorage(Storage<Comp1>())
    w.addStorage(Storage<Comp2>())
    let s1 = w[Comp1.self]
    let s2 = w[Comp2.self]

    for _ in 0..<200 {
        _ = w.createEntity()
    } 

    for _ in 0..<200 {
        let e = w.createEntity()
        s1.addEntity(newEntity: e, Comp1())
    } 

    for _ in 0..<100 {
        let e = w.createEntity()
        s1.addEntity(newEntity: e, Comp1())
        s2.addEntity(newEntity: e, Comp2())
    } 

    for _ in 0..<900 {
        let e = w.createEntity()
        s2.addEntity(newEntity: e, Comp2())
    }

    let q = w.queryDraft().buildQuery()
    // all 200 + 200 + 100 + 900
    #expect(q.query().count == 1400)

    let q2 = w.queryDraft().without(Comp2.self).buildQuery()
    // no comp + comp1 = 200 + 200 = 400
    #expect(q2.query().count == 400)

    let q3 = w.queryDraft().without(Comp2.self).without(Comp1.self).buildQuery()
    // no comp
    #expect(q3.query().count == 200)

    let q4 = w.queryDraft().with(Comp1.self).with(Comp2.self).buildQuery()
    // with Comp1 && Comp2 = 100
    #expect(q4.query().count == 100)

}


@Test func testCommand() async throws {
    let w = World()
    let events = try w.applyCommand(.spawn).get()
    let eventsView = EventView(events: events)

    let eids = eventsView.spawnedEntities
    #expect(eids.count == 1)
    let eid = eids[0]
    let s1 = w[Comp1.self]
    let s2 = w[Comp2.self]

    s1.addEntity(newEntity: eid, Comp1())
    s2.addEntity(newEntity: eid, Comp2())

    let events2 = try w.applyCommand(.despwan(eid)).get()
    let events2View = EventView(events: events2)
    let eids2 = events2View.despawnedEntities
    #expect(eids2.count == 1)
    let eid2 = eids2[0]
    #expect(eid == eid2)
    
    let cids = events2View.removedComponents(of: eid2)
    #expect(cids.count == 2)
    let removed = Set(cids)
    let expected: Set<ComponentId> = [s1.componentId, s2.componentId]
    #expect(removed == expected)

    let event3 = try w.applyCommand( .addEntitiyComponent(eid, Comp1()) ).get()
    let events3View = EventView(events: event3)
    let cid3 = events3View.addedComponents(of: eid)
    print(cid3)
    


}


@Test func testCommand_doubleDespawnFails() async throws {
    let w = World()
    let events = try w.applyCommand(.spawn).get()
    let eid = EventView(events: events).spawnedEntities[0]

    _ = try w.applyCommand(.despwan(eid)).get()

    guard case .failure(let err) = w.applyCommand(.despwan(eid)) else {
        #expect(Bool(false), "Expected failure")
        return
    }
    #expect(err == .entitiyNotAlive(eid))

}

func printBit(_ val: UInt64) {
    for i in (0..<64).reversed() {
        let bit = (val >> i) & 1
        print(bit == 0 ? "." : "1", terminator: "")
    }
    print()
}

@Test func testP64() async throws {
    let page = Page64()
    printBit(page.mask)

    page.add(3, SparseEntry(denseIdx: 55, gen: 2))
    printBit(page.mask)
    
    page.add(63, SparseEntry(denseIdx: 55, gen: 2))
    printBit(page.mask)

    print(page)

    page.remove(63)
    printBit(page.mask)
    print(page)

    print(page.entityOnPage[3])
    page.update(3) { se in
        se.denseIdx = 1_000_000
        se.gen = -20_000
    }
    print(page.entityOnPage[3])
}   