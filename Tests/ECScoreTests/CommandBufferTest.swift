import Testing
@testable import ECScore

struct MovedTag: TagComponent {}

@Test func CommandBufferTest() async throws {
    let base = makeBootedPlatform()
    let mvToken = interop(base, MovedTag.self)
    let pToken = interop(base, Position.self)
    let n = 8888

    emplace(base, tokens: pToken) {
        entities, pack in
        var pSt = pack.storages

        for i in 1...n {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: Float(i), y: Float(i + 1)))
        }
    }

    var cmdbf = mvToken.getCommandBuffer(base: base)

    view(base: base, with: pToken) {
        iterId, pos in
        if (iterId.eidId % 2 == 0) { 

            // update
            pos.fast.x += 1 
            // add moved tag
            cmdbf.addCommand(iterId)
        }
    }

    // observer system use tag to get entity
    var count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        let d = (pos.fast.x - pos.fast.y)
        #expect(d == 0.0)
        count += 1
    }

    #expect(count == (n / 2))
    
    cmdbf.removeAll()
    cmdbf.removeAll() // idempotent

    count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        let d = (pos.fast.x - pos.fast.y)
        #expect(d == 0.0)
        count += 1
    }

    #expect(count == 0)

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

    count = 0
    view(base: base, with: pToken, withTag: mvToken) {
        iterId, pos in
        let d = (pos.fast.x - pos.fast.y)
        #expect(d == 0.0)
        count += 1
    }

    #expect(count == 0)
}

