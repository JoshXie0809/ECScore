public struct SparseSet_L2_2_Tag<TC: TagComponent>: AnySparseSet {
    public typealias T = TC

    @usableFromInline
    private(set) var blockMask: UInt64 = 0
    @usableFromInline
    private(set) var pageMasks: ContiguousArray<UInt64>

    @usableFromInline
    private(set) var _count: Int = 0
    
    @inlinable
    public var count: Int { _count }

    @inlinable
    public init() {
        self.pageMasks = ContiguousArray<UInt64>(repeating: 0, count: 64)
    }

    @inlinable
    public mutating func add(_ eid: EntityId, _ component: TC = TC()) {
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
    public mutating func get(_ eid: EntityId) -> TC? {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        guard (pageMasks[pageIdx] & bit) != 0 else { return nil }
        return TC()
    }


    // MARK: - PFStorage 指標介面
    /// 供 ViewPlan 獲取數據陣列指標
    @inlinable
    public mutating func getRawDataPointer() -> UnsafeMutablePointer<TC> {
        fatalError("cannot get components pointer for Tag Components")
    }

    /// 【核心改進】提供連續的 PageMasks 指標，不再需要 PagePtr 逐級查找
    @inlinable
    public func getPageMasksPointer() -> UnsafePointer<UInt64> {
        return pageMasks.withUnsafeBufferPointer { $0.baseAddress! }
    }

    /// 提供連續的 SparseEntries 指標，供快速索引轉換
    @inlinable
    public func getSparseEntriesPointer() -> SSEPtr<TC>  {
        fatalError("cannot get SparseEntries Pointer for Tag Component")
    }
}
