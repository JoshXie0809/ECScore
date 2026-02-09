let HardwareBufferPadding = 16

public struct SparseSet_L2_2<T: Component> {
    @usableFromInline
    private(set) var blockMask: UInt64 = 0
    @usableFromInline
    private(set) var pageMasks: ContiguousArray<UInt64>
    
    @usableFromInline
    private(set) var sparseEntries: ContiguousArray<SparseSetEntry>
    @usableFromInline
    private(set) var components: ContiguousArray<T>
    @usableFromInline
    private(set) var reverseEntities: ContiguousArray<BlockId>

    @inlinable public var count: Int { components.count }

    public init() {
        self.pageMasks = ContiguousArray<UInt64>(repeating: 0, count: 64)
        
        // 使用一塊連續的記憶體存放 4096 個 Sparse 索引
        self.sparseEntries = ContiguousArray<SparseSetEntry>(
            repeating: SparseSetEntry(compArrIdx: -1), 
            count: 4096 + (HardwareBufferPadding * 256)
        )
        
        self.components = ContiguousArray<T>()
        self.components.reserveCapacity(4096 + HardwareBufferPadding)
        
        self.reverseEntities = ContiguousArray<BlockId>()
        self.reverseEntities.reserveCapacity(4096 + HardwareBufferPadding)
    }

    // MARK: - 符合 PFStorage 介面的操作

    @inlinable
    public mutating func add(_ eid: EntityId, _ component: T) {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        // 利用 pageMasks 陣列進行快速存在檢查
        guard (pageMasks[pageIdx] & bit) == 0 else { return }

        let newDenseIdx = Int16(components.count)
        components.append(component)
        reverseEntities.append(BlockId(offset: Int16(offset)))

        sparseEntries[offset].compArrIdx = newDenseIdx
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

        let removeIdx = Int(sparseEntries[offset].compArrIdx)
        let lastIdx = components.count - 1

        if removeIdx < lastIdx {
            let lastBlockId = reverseEntities[lastIdx]
            components[removeIdx] = components[lastIdx]
            reverseEntities[removeIdx] = lastBlockId
            
            let movedOffset = Int(lastBlockId.offset)
            sparseEntries[movedOffset].compArrIdx = Int16(removeIdx)
        }

        components.removeLast()
        reverseEntities.removeLast()

        pageMasks[pageIdx] &= ~bit
        if pageMasks[pageIdx] == 0 {
            blockMask &= ~(UInt64(1) << pageIdx)
        }
        sparseEntries[offset].compArrIdx = -1
    }



    // MARK: - PFStorage 指標介面
    /// 供 ViewPlan 獲取數據陣列指標
    @inlinable
    public mutating func getRawDataPointer() -> UnsafeMutablePointer<T> {
        return components.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }

    /// 【核心改進】提供連續的 PageMasks 指標，不再需要 PagePtr 逐級查找
    @inlinable
    public func getPageMasksPointer() -> UnsafePointer<UInt64> {
        return pageMasks.withUnsafeBufferPointer { $0.baseAddress! }
    }

    /// 提供連續的 SparseEntries 指標，供快速索引轉換
    @inlinable
    public func getSparseEntriesPointer() -> SSEPtr<T>  {
        return SSEPtr(ptr: sparseEntries.withUnsafeBufferPointer { $0.baseAddress! })
    }
}

public struct SSEPtr<T> {
    @usableFromInline
    let ptr: UnsafePointer<SparseSetEntry>
    
    @usableFromInline
    init(ptr: UnsafePointer<SparseSetEntry>) {
        self.ptr = ptr
    }
}