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

