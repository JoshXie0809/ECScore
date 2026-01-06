typealias BlockOffset = Int16
typealias CompArrayIndex = Int16

struct SparseSetEntry {
    var compArrIdx: CompArrayIndex // 紀錄在 dense Array 4096 中的第幾個位置
}

struct BlockId {
    var offset: BlockOffset
    var version: Int // gen is for validation
}

func printBit(_ val: UInt64) {
    for i in (0..<64).reversed() {
        let bit = (val >> i) & 1
        print(bit == 0 ? "." : "1", terminator: "")
    }
    print()
}

struct Page64: CustomStringConvertible {
    private(set) var pageMask: UInt64 = 0
    private(set) var activeCount: Int = 0
    private(set) var entityOnPage = 
        ContiguousArray<SparseSetEntry>(
            repeating: SparseSetEntry(compArrIdx: Int16(-1)), 
            count: 64
        )

    var description: String {
        "Page64(n:\(activeCount))"
    }

    @inline(__always)
    mutating func add(_ index: Int, _ sparseEntry: SparseSetEntry) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(pageMask & bit == 0, "double add on Page64")

        entityOnPage[index] = sparseEntry
        pageMask |= bit
        activeCount += 1
    }

    @inline(__always)
    mutating func remove(_ index: Int) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(pageMask & bit != 0, "remove inactive slot")
        
        // entityOnPage[index] = SparseEntry(denseIdx: -1) // inactive
        pageMask &= ~bit
        activeCount -= 1
    }

    @inline(__always)
    mutating func update(_ index: Int, _ updateFn: (inout SparseSetEntry) -> Void ) {
        precondition(index >= 0 && index < 64, "invalid Page64 index")
        let bit = UInt64(1) << index
        precondition(pageMask & bit != 0, "update inactive slot")

        updateFn(&entityOnPage[index])
    }

    // 安全版：給一般邏輯使用
    @inline(__always)
    func get(_ index: Int) -> SparseSetEntry? {
        let bit = UInt64(1) << index
        return (pageMask & bit != 0) ? entityOnPage[index] : nil
    }

    @inline(__always)
    func getUnchecked(_ index: Int) -> SparseSetEntry {
        return entityOnPage[index]
    }

    @inline(__always)
    mutating func reset() {
        self.pageMask = 0
        self.activeCount = 0
        // 注意：如果你不介意舊資料留在裡面，甚至不需要清空 entityOnPage
        // 因為 mask = 0 已經讓那些資料在邏輯上不可見了
    }
}

// struct SparseSet_L2<T: Component>: Component {
//     private(set) var sparse = Block64_L2()
//     private(set) var dense: ContiguousArray<T> = ContiguousArray<T>()
//     private(set) var entities: ContiguousArray<BlockId> = ContiguousArray<BlockId>()
//     // for parallel usage: 讀寫分離
//     private var denseBuffer: ContiguousArray<T> = ContiguousArray<T>()
//     init() {
//         self.dense.reserveCapacity(4096)
//         self.denseBuffer.reserveCapacity(4096)
//         self.entities.reserveCapacity(4096)
//     }
// }