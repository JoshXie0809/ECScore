import Testing
@testable import ECScore

struct MovedTag: TagComponent {}

@Test func CommandBufferTest() async throws {
    let base = makeBootedPlatform()
    let mvToken = interop(base, MovedTag.self)
    let pToken = interop(base, Position.self)
    let n = 512

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages

        for i in 1...n {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: Float(i), y: Float(i + 1)))
        }
    }

    // NOTE:
    // `getCommandBuffer` is used here as an immediate tag mutator.
    // These tests assert observable final state after each write sequence.
    var tagMutator = mvToken.getCommandBuffer(base: base)

    view(base: base, with: pToken) { iterId, pos in
        if iterId.eidId % 2 == 0 {
            pos.fast.x += 1
            tagMutator.addCommand(iterId)
            tagMutator.addCommand(iterId) // idempotent add
        }
    }

    var count = 0
    view(base: base, with: pToken, withTag: mvToken) { _, pos in
        let d = pos.fast.x - pos.fast.y
        #expect(d == 0.0)
        count += 1
    }
    #expect(count == (n / 2))

    tagMutator.removeAll()
    tagMutator.removeAll() // idempotent clear

    count = 0
    view(base: base, with: pToken, withTag: mvToken) { _, _ in
        count += 1
    }
    #expect(count == 0)

    // next frame
    view(base: base, with: pToken) { iterId, pos in
        if iterId.eidId % 2 == 0 {
            pos.fast.x += 1
            tagMutator.addCommand(iterId)
        }
    }

    count = 0
    view(base: base, with: pToken, withTag: mvToken) { _, pos in
        let d = pos.fast.x - pos.fast.y
        #expect(d == 1.0)
        count += 1
    }
    #expect(count == (n / 2))

    tagMutator.removeAll()
    tagMutator.removeAll()

    count = 0
    view(base: base, with: pToken, withTag: mvToken) { _, _ in
        count += 1
    }
    #expect(count == 0)
}

@Test func TagMutation_LastWriteWins() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let mvToken = interop(base, MovedTag.self)
    let n = 128

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for i in 0..<n {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: Float(i), y: 0))
        }
    }

    var tagMutator = mvToken.getCommandBuffer(base: base)

    // Final state semantics (immediate mutation):
    // mod 0 -> add, remove, add => add
    // mod 1 -> add, remove      => remove
    // mod 2 -> remove, add      => add
    // mod 3 -> remove, remove   => remove
    view(base: base, with: pToken) { iterId, _ in
        switch iterId.eidId & 3 {
        case 0:
            tagMutator.addCommand(iterId)
            tagMutator.removeCommand(iterId)
            tagMutator.addCommand(iterId)
        case 1:
            tagMutator.addCommand(iterId)
            tagMutator.removeCommand(iterId)
        case 2:
            tagMutator.removeCommand(iterId)
            tagMutator.addCommand(iterId)
        default:
            tagMutator.removeCommand(iterId)
            tagMutator.removeCommand(iterId)
        }
    }

    var taggedCount = 0
    view(base: base, with: (), withTag: mvToken) { _ in
        taggedCount += 1
    }
    #expect(taggedCount == (n / 2))

    tagMutator.removeAll()
    var finalCount = 0
    view(base: base, with: (), withTag: mvToken) { _ in
        finalCount += 1
    }
    #expect(finalCount == 0)
}

@Test func DynamicRandomUpdateWithCountTest() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let mvToken = interop(base, MovedTag.self)

    let totalEntities = 8_192
    var rng = Xoshiro128(seed: 999)

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for _ in 0..<totalEntities {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: 0, y: 0))
        }
    }

    var tagMutator = mvToken.getCommandBuffer(base: base)
    var expectedTagged = Set<Int>()

    // Deterministic final-state patterns:
    // 0 -> add                    => tagged
    // 1 -> add, remove            => untagged
    // 2 -> add, remove, add       => tagged
    // 3 -> remove, add, remove    => untagged
    view(base: base, with: pToken) { iterId, pos in
        if (rng.next() & 7) == 0 {
            pos.fast.x += 1.0
            switch Int(rng.next() & 3) {
            case 0:
                tagMutator.addCommand(iterId)
                expectedTagged.insert(iterId.eidId)
            case 1:
                tagMutator.addCommand(iterId)
                tagMutator.removeCommand(iterId)
                expectedTagged.remove(iterId.eidId)
            case 2:
                tagMutator.addCommand(iterId)
                tagMutator.removeCommand(iterId)
                tagMutator.addCommand(iterId)
                expectedTagged.insert(iterId.eidId)
            default:
                tagMutator.removeCommand(iterId)
                tagMutator.addCommand(iterId)
                tagMutator.removeCommand(iterId)
                expectedTagged.remove(iterId.eidId)
            }
        }
    }

    var actualTagged = Set<Int>()
    view(base: base, with: pToken, withTag: mvToken) { iterId, pos in
        #expect(pos.fast.x == 1.0)
        actualTagged.insert(iterId.eidId)
    }

    #expect(actualTagged == expectedTagged)

    tagMutator.removeAll()

    var finalCount = 0
    view(base: base, with: (), withTag: mvToken) { _ in finalCount += 1 }
    #expect(finalCount == 0)
}

@Test func TagMutation_RemoveSelfDuringIteration_SnapshotSemantics() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let mvToken = interop(base, MovedTag.self)
    let n = 256

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        var tagMutator = mvToken.getCommandBuffer(base: base)

        for i in 0..<n {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: Float(i), y: 0))
            tagMutator.addCommand(eid)
        }
    }

    var tagMutator = mvToken.getCommandBuffer(base: base)
    var visited = 0
    view(base: base, with: (), withTag: mvToken) { iterId in
        // Snapshot semantics: removing current entity must not skip remaining entities in this pass.
        tagMutator.removeCommand(iterId)
        visited += 1
    }
    #expect(visited == n)

    var remaining = 0
    view(base: base, with: (), withTag: mvToken) { _ in
        remaining += 1
    }
    #expect(remaining == 0)
}

@Test func TagMutation_DestroyAndReuseId_DoesNotInheritTag() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let mvToken = interop(base, MovedTag.self)
    let n = 256
    let destroyCount = n / 2

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        var tagMutator = mvToken.getCommandBuffer(base: base)
        var created = [EmplaceEntityId]()
        created.reserveCapacity(n)

        for _ in 0..<n {
            let eid = entities.createEntity()
            created.append(eid)
            pSt.addComponent(eid, Position(x: 1.0, y: 0))
            tagMutator.addCommand(eid)
        }

        // Destroy half; IDs should be recycled on subsequent spawns.
        for i in 0..<destroyCount {
            // pSt.removeComponent(created[i])
            // tagMutator.removeCommand(created[i]) // now I use lazy despawn to entity
            // entities.destroyEntity(created[i])

            entities.destroyEntityAndRemoveComponents(created[i], base)
        }
    }

    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for _ in 0..<destroyCount {
            let eid = entities.createEntity()
            pSt.addComponent(eid, Position(x: 99.0, y: 0))
        }
    }

    var taggedCount = 0
    var reusedTaggedCount = 0
    view(base: base, with: pToken, withTag: mvToken) { _, pos in
        taggedCount += 1
        if pos.fast.x == 99.0 {
            reusedTaggedCount += 1
        }
    }

    #expect(taggedCount == (n - destroyCount))
    #expect(reusedTaggedCount == 0)
}

struct TargetTag: TagComponent {}
struct ProcessedTag: TagComponent {}

@Test func ChainReactionSystemTest() async throws {
    let base = makeBootedPlatform()

    let pToken = interop(base, Position.self)
    let targetTag = interop(base, TargetTag.self)
    let processedTag = interop(base, ProcessedTag.self)

    let total = 4_096
    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for i in 0..<total {
            let eid = entities.createEntity()
            let posX = i < total / 2 ? -1.0 : 1.0
            pSt.addComponent(eid, Position(x: Float(posX), y: 0))
        }
    }

    // System A: mark positive-x entities
    var targetMutator = targetTag.getCommandBuffer(base: base)
    view(base: base, with: pToken) { iterId, pos in
        if pos.fast.x > 0 {
            targetMutator.addCommand(iterId)
        }
    }

    // System B: consume TargetTag, move to ProcessedTag
    var processedMutator = processedTag.getCommandBuffer(base: base)
    var targetRemover = targetTag.getCommandBuffer(base: base)

    var processedCount = 0
    view(base: base, with: pToken, withTag: targetTag) { iterId, pos in
        pos.fast.x *= 2.0
        targetRemover.removeCommand(iterId)
        processedMutator.addCommand(iterId)
        processedCount += 1
    }

    // System C: verify final tag set
    var finalCheckCount = 0
    view(base: base, with: (), withTag: processedTag) { _ in
        finalCheckCount += 1
    }

    #expect(processedCount == total / 2)
    #expect(finalCheckCount == total / 2)

    var leftoverTags = 0
    view(base: base, with: (), withTag: targetTag) { _ in leftoverTags += 1 }
    #expect(leftoverTags == 0)
}

@Test func ChainReactionSystemTest_IdempotentStress() async throws {
    let base = makeBootedPlatform()

    let pToken = interop(base, Position.self)
    let targetTag = interop(base, TargetTag.self)
    let processedTag = interop(base, ProcessedTag.self)

    let total = 2_048
    emplace(base, tokens: pToken) { entities, pack in
        var pSt = pack.storages
        for i in 0..<total {
            let eid = entities.createEntity()
            let posX = i < total / 2 ? -1.0 : 1.0
            pSt.addComponent(eid, Position(x: Float(posX), y: 0))
        }
    }

    // Repeated writes for same entity must converge to final state.
    var targetMutator = targetTag.getCommandBuffer(base: base)
    view(base: base, with: pToken) { iterId, pos in
        if pos.fast.x > 0 {
            targetMutator.addCommand(iterId)
            targetMutator.addCommand(iterId)
            targetMutator.addCommand(iterId)
            targetMutator.addCommand(iterId)
            targetMutator.addCommand(iterId)
        }
    }

    var processedMutator = processedTag.getCommandBuffer(base: base)
    var targetRemover = targetTag.getCommandBuffer(base: base)

    var processedCount = 0
    view(base: base, with: pToken, withTag: targetTag) { iterId, pos in
        pos.fast.x *= 2.0

        targetRemover.removeCommand(iterId)
        targetRemover.removeCommand(iterId)

        processedMutator.addCommand(iterId)
        processedMutator.addCommand(iterId)
        processedMutator.addCommand(iterId)

        processedCount += 1
    }

    var finalCheckCount = 0
    view(base: base, with: (), withTag: processedTag) { _ in
        finalCheckCount += 1
    }

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

    var targetMutator = targetTag.getCommandBuffer(base: base)

    let total = 2_000
    emplace(base, tokens: pToken) { entities, pack in
        var st = pack.storages

        for _ in 0..<total {
            let eid = entities.createEntity()
            st.addComponent(eid, Position(x: 1.0, y: 0))
            targetMutator.addCommand(eid)
        }
    }

    // Stage A: remove half of tags.
    var targetRemover = targetTag.getCommandBuffer(base: base)
    var count = 0

    view(base: base, with: (), withTag: targetTag) { iterId in
        if count % 2 == 0 {
            targetRemover.removeCommand(iterId)
        }
        count += 1
    }

    // Stage B: cleanup components by `withoutTag`.
    var posRemover = pToken.getCommandBuffer(base: base)
    var reactiveCount = 0

    view(base: base, with: pToken, withoutTag: targetTag) { iterId, _ in
        posRemover.removeCommand(iterId)
        reactiveCount += 1
    }

    #expect(reactiveCount == (total / 2))

    var finalCount = 0
    view(base: base, with: pToken) { _, _ in finalCount += 1 }
    #expect(finalCount == (total / 2))
}
