struct SparseEntry {
    var denseIdx: Int
    var gen: Int
}

struct Page64: CustomStringConvertible {
    private(set) var mask: UInt64 = 0
    private(set) var activeCount: Int = 0
    private(set) var entityOnPage = ContiguousArray<SparseEntry>(
        repeating: SparseEntry(denseIdx: -1, gen: -1), 
        count: 64
    )

    var description: String {
        "Page64(n:\(activeCount))"
    }

    @inline(__always)
    mutating func add(_ index: Int, _ sparseEntry: SparseEntry) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(mask & bit == 0, "double add on Page64")

        entityOnPage[index] = sparseEntry
        mask |= bit
        activeCount += 1
    }

    @inline(__always)
    mutating func remove(_ index: Int) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(mask & bit != 0, "remove inactive slot")
        
        // entityOnPage[index] = SparseEntry(denseIdx: -1, gen: -1) // inactive
        mask &= ~bit
        activeCount -= 1
    }

    @inline(__always)
    mutating func update(_ index: Int, _ updateFn: (inout SparseEntry) -> Void ) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(mask & bit != 0, "update inactive slot")

        updateFn(&entityOnPage[index])
    }

    // 安全版：給一般邏輯使用
    @inline(__always)
    func get(_ index: Int) -> SparseEntry? {
        let bit = UInt64(1) << index
        return (mask & bit != 0) ? entityOnPage[index] : nil
    }

    // 暴力版：給已知 index 必存在的系統迴圈使用
    @inline(__always)
    func getUnchecked(_ index: Int) -> SparseEntry {
        return entityOnPage[index]
    }

    @inline(__always)
    mutating func reset() {
        self.mask = 0
        self.activeCount = 0
        // 注意：如果你不介意舊資料留在裡面，甚至不需要清空 entityOnPage
        // 因為 mask = 0 已經讓那些資料在邏輯上不可見了
    }
}

final class Block64_L2 { // Layer 2
    private(set) var blockMask: UInt64 = 0
    private(set) var activePageCount: Int = 0
    private(set) var activeEntityCount: Int = 0
    private(set) var pageOnBlock: ContiguousArray<Page64> = 
        ContiguousArray<Page64>(repeating: Page64(), count: 64)

    @inline(__always)
    func addPage(_ index: Int) {
        precondition(index >= 0 && index < 64, "invalid Block64_L2 index")
        let bit = UInt64(1) << index
        precondition(blockMask & bit == 0, "double add Page to Block64_L2")

        // 標記 active
        blockMask |= bit
        activePageCount += 1
    }

    @inline(__always)
    func removePage(_ index: Int) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(blockMask & bit != 0, "remove inactive slot")
        
        let page = pageOnBlock[index]
        pageOnBlock[index].reset()

        blockMask &= ~bit
        activePageCount -= 1
        activeEntityCount -= page.activeCount
    }
}
