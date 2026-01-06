import Testing
@testable import ECScore

@Test func b64_test1() async throws {
    var sparse = Block64_L2()
    let ssEntry = SparseSetEntry(compArrIdx: 321)

    sparse.addEntityOnBlock(3095, ssEntry: ssEntry)
    let pageIdx = 3095 >> 6
    let slotIdx = 3095 & 0x003F

    // mask test
    let bit = UInt64(1) << pageIdx
    #expect(sparse.blockMask & bit != 0)

    let pageBit = UInt64(1) << slotIdx
    #expect(sparse.pageOnBlock[pageIdx].pageMask & pageBit != 0)

}