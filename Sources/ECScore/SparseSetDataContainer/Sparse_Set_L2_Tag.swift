public struct SparseSet_L2_2_Tag<TC: Component>: AnySparseSet {
    public typealias T = TC
    
    public var blockMask: UInt64 = 0
    public var pageMasks: ContiguousArray<UInt64>

    @usableFromInline
    private(set) var _count: Int = 0
    
    @inlinable
    @inline(__always)
    public var count: Int { _count }

    @inlinable
    @inline(__always)
    public init() {
        self.pageMasks = ContiguousArray<UInt64>(repeating: 0, count: 64)
    }

    @inlinable
    @inline(__always)
    public mutating func add(_ eid: EntityId, _ component: consuming TC = TC()) {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        // 利用 pageMasks 陣列進行快速存在檢查
        guard (pageMasks[pageIdx] & bit) == 0 else { return }

        _count += 1
        pageMasks[pageIdx] |= bit
        blockMask |= (UInt64(1) << pageIdx)
    }

    @inlinable
    @inline(__always)
    public mutating func remove(_ eid: EntityId) {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        guard (pageMasks[pageIdx] & bit) != 0 else { return }
        _count -= 1

        pageMasks[pageIdx] &= ~bit
        if pageMasks[pageIdx] == 0 {
            blockMask &= ~(UInt64(1) << pageIdx)
        }

        // sparseEntries[sparseIndex].compArrIdx = -1
    }

    @inlinable
    @inline(__always)
    public func get(_ eid: EntityId) -> TC? {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        guard (pageMasks[pageIdx] & bit) != 0 else { return nil }
        return TC()
    }

    /// 【核心改進】提供連續的 PageMasks 指標，不再需要 PagePtr 逐級查找
    @inlinable
    @inline(__always)
    public func getPageMasksPointer() -> UnsafePointer<UInt64> {
        return pageMasks.withUnsafeBufferPointer { $0.baseAddress! }
    }
}
