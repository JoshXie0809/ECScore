struct SparseSetEntry {
    var denseIdx: Int16 // 紀錄在 dense Array 4096 中的第幾個位置
    var gen: Int
}

struct BlockId {
    var offset: Int16
}

struct Page64: CustomStringConvertible {
    private(set) var mask: UInt64 = 0
    private(set) var activeCount: Int = 0
    private(set) var entityOnPage: ContiguousArray<SparseSetEntry> = ContiguousArray<SparseSetEntry>(
        repeating: SparseSetEntry(denseIdx: -1, gen: -1), 
        count: 64
    )

    var description: String {
        "Page64(n:\(activeCount))"
    }

    @inline(__always)
    mutating func add(_ index: Int, _ sparseEntry: SparseSetEntry) {
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
    mutating func update(_ index: Int, _ updateFn: (inout SparseSetEntry) -> Void ) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(mask & bit != 0, "update inactive slot")

        updateFn(&entityOnPage[index])
    }

    // 安全版：給一般邏輯使用
    @inline(__always)
    func get(_ index: Int) -> SparseSetEntry? {
        let bit = UInt64(1) << index
        return (mask & bit != 0) ? entityOnPage[index] : nil
    }

    // 暴力版：給已知 index 必存在的系統迴圈使用
    @inline(__always)
    func getUnchecked(_ index: Int) -> SparseSetEntry {
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

struct Block64_L2 { // Layer 2
    private(set) var blockMask: UInt64 = 0
    private(set) var activePageCount: Int = 0
    private(set) var activeEntityCount: Int = 0
    private(set) var pageOnBlock: ContiguousArray<Page64> = 
        ContiguousArray<Page64>(repeating: Page64(), count: 64)

    @inline(__always)
    mutating func addPage(_ index: Int) {
        precondition(index >= 0 && index < 64, "invalid Block64_L2 index")
        let bit = UInt64(1) << index
        precondition(blockMask & bit == 0, "double add Page to Block64_L2")

        // 標記 active
        blockMask |= bit
        activePageCount += 1
    }

    @inline(__always)
    mutating func removePage(_ index: Int) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(blockMask & bit != 0, "remove inactive slot")

        blockMask &= ~bit
        activePageCount -= 1
        activeEntityCount -= pageOnBlock[index].activeCount
        pageOnBlock[index].reset()

    }
}

struct SparseSet_L2<T: Component>: Component {
    private(set) var sparse = Block64_L2()
    private(set) var dense: ContiguousArray<T> = ContiguousArray<T>()
    private(set) var entities: ContiguousArray<BlockId> = ContiguousArray<BlockId>()
    // for parallel usage: 讀寫分離
    private var denseBuffer: ContiguousArray<T> = ContiguousArray<T>()

    init() {
        self.dense.reserveCapacity(4096)
        self.denseBuffer.reserveCapacity(4096)
        self.entities.reserveCapacity(4096)
    }
}