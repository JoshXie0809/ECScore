import Testing
@testable import ECScore

@Test func b64_test1() async throws {
    var sparse = Block64_L2()
    let ssEntry = SparseSetEntry(compArrIdx: 321)

    let offset = 3095
    sparse.addEntityOnBlock(3095, ssEntry: ssEntry)
    let pageIdx = offset >> 6
    let slotIdx = offset & 0x003F

    // mask test
    let bit = UInt64(1) << pageIdx
    #expect(sparse.blockMask & bit != 0)
    let pageBit = UInt64(1) << slotIdx
    #expect(sparse.pageOnBlock[pageIdx].pageMask & pageBit != 0)
    #expect(sparse.contains(offset))
    #expect(sparse.getUnchecked(offset).compArrIdx == 321)
    #expect(sparse.activePageCount == 1)
    #expect(sparse.activeEntityCount == 1)

    // remove test
    sparse.removeEntityOnBlock(offset)
    // mask test
    #expect(sparse.blockMask & bit == 0)
    #expect(sparse.pageOnBlock[pageIdx].pageMask & pageBit == 0)
    #expect(!sparse.contains(offset))
    #expect(sparse.activePageCount == 0)
    #expect(sparse.activeEntityCount == 0)


    // alter test
    sparse.addEntityOnBlock(3092, ssEntry: ssEntry)
    sparse.addEntityOnBlock(30, ssEntry: ssEntry)

    #expect(sparse.activePageCount == 2)
    #expect(sparse.activeEntityCount == 2)
    #expect(sparse.getUnchecked(3092).compArrIdx == 321)

    sparse.updateComponentArrayIdx(3092) { ssEntry in
        ssEntry.compArrIdx = 12
    }

    #expect(sparse.getUnchecked(3092).compArrIdx == 12)
    
}