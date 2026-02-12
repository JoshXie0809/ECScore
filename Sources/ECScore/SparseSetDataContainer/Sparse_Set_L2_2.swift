public typealias BlockOffset = Int16
public typealias CompArrayIndex = Int16

public struct SparseSetEntry: Sendable {
    public var compArrIdx: CompArrayIndex 
    
    @inline(__always)
    public init(compArrIdx: CompArrayIndex) {
        self.compArrIdx = compArrIdx
    }
}

public struct BlockId: Sendable {
    public var offset: BlockOffset
    
    @inline(__always)
    public init(offset: BlockOffset) {
        self.offset = offset
    }
}

func printBit(_ val: UInt64) {
    for i in (0..<64).reversed() {
        let bit = (val >> i) & 1
        print(bit == 0 ? "." : "1", terminator: "")
    }
    print()
}



public let HardwareBufferPadding = 16

public struct SparseSet_L2_2<C: Component>: AnySparseSet {
    public typealias T = C
    @usableFromInline
    private(set) var blockMask: UInt64 = 0
    @usableFromInline
    private(set) var pageMasks: ContiguousArray<UInt64>
    
    @usableFromInline
    private(set) var sparseEntries: ContiguousArray<SparseSetEntry>
    @usableFromInline
    private(set) var components: ContiguousArray<C>
    @usableFromInline
    private(set) var reverseEntities: ContiguousArray<BlockId>
    @usableFromInline let staggerOffset: Int
    @usableFromInline let sparseStaggerOffset: Int

    @inlinable public var count: Int { components.count - staggerOffset }

    @inlinable
    public init() {
        self.pageMasks = ContiguousArray<UInt64>(repeating: 0, count: 64)
        
        // let oid = ObjectIdentifier(C.self)
        // let staggerIdx = abs(oid.hashValue) & 7
        // let byteOffset = staggerIdx * 64

        self.staggerOffset = 0 // max(byteOffset / MemoryLayout<C>.stride, 1)
        self.sparseStaggerOffset = 0 // max(byteOffset / MemoryLayout<SparseSetEntry>.stride, 1)

        // 定義安全區大小：16 條 Cache Lines (1024 Bytes)
        let paddingBytes = HardwareBufferPadding * 64 
        
        // 1. SparseEntries (維持原樣，雖然有點浪費但很安全)
        // 這裡直接加 1024 個元素，如果 Entry 是 2 bytes，就是 2048 bytes padding，足夠安全。
        self.sparseEntries = ContiguousArray<SparseSetEntry>(
            repeating: SparseSetEntry(compArrIdx: -1), 
            count: 4096 + (HardwareBufferPadding * 64) + sparseStaggerOffset
        )
        
        // 2. Components (這部分你寫對了！)
        // 計算 T 需要多少個元素才能填滿 1024 bytes
        self.components = ContiguousArray<C>()
        let paddingElements = (paddingBytes + MemoryLayout<C>.stride - 1) / MemoryLayout<C>.stride
        self.components.reserveCapacity(4096 + paddingElements + staggerOffset)
        
        for _ in 0..<staggerOffset { self.components.append(C()) }
        
        // 3. ReverseEntities (【修正這裡】)
        self.reverseEntities = ContiguousArray<BlockId>()
        
        // 計算 BlockId 需要多少個元素才能填滿 1024 bytes
        // 假設 BlockId 是 Int16 (2 bytes)，這裡會算出 512 個元素
        let revPaddingElements = (paddingBytes + MemoryLayout<BlockId>.stride - 1) / MemoryLayout<BlockId>.stride
        
        // 使用計算出的 revPaddingElements，而不是 HardwareBufferPadding
        self.reverseEntities.reserveCapacity(4096 + revPaddingElements + staggerOffset)
        
        let invalidBlock = BlockId(offset: -1)
        for _ in 0..<staggerOffset { self.reverseEntities.append(invalidBlock) }
    }

    // MARK: - 符合 PFStorage 介面的操作

    @inlinable
    public mutating func add(_ eid: EntityId, _ component: C) {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        // 利用 pageMasks 陣列進行快速存在檢查
        guard (pageMasks[pageIdx] & bit) == 0 else { return }
        let logicalIdx = Int16(components.count - staggerOffset)

        components.append(component)
        reverseEntities.append(BlockId(offset: Int16(offset)))
        sparseEntries[sparseStaggerOffset + Int(offset)].compArrIdx = logicalIdx // 存入邏輯索引

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

        let sparseIndex = sparseStaggerOffset + Int(offset)
        
        // 1. 從 Sparse 表拿到的是「邏輯索引」 (例如 0)
        let removeLogicalIdx = Int(sparseEntries[sparseIndex].compArrIdx)
        
        // 2. 【關鍵修正】轉成「物理索引」才能操作 components 陣列
        // 物理位置 = 邏輯位置 + 偏移量
        let removePhysicalIdx = removeLogicalIdx + staggerOffset
        
        let lastPhysicalIdx = components.count - 1

        if removePhysicalIdx < lastPhysicalIdx {
            let lastBlockId = reverseEntities[lastPhysicalIdx]
            
            // Swap Components (使用物理索引)
            components[removePhysicalIdx] = components[lastPhysicalIdx]
            
            // Swap Reverse Lookups (使用物理索引)
            reverseEntities[removePhysicalIdx] = lastBlockId
            
            // Update Sparse Entry
            let movedOffset = Int(lastBlockId.offset)

            // 【關鍵修正】存入 Sparse 表的必須是「邏輯索引」
            // 因為最後一個元素搬到了 removeLogicalIdx 的位置，所以它的新邏輯索引就是 removeLogicalIdx
            sparseEntries[sparseStaggerOffset + movedOffset].compArrIdx = Int16(removeLogicalIdx)
        }

        components.removeLast()
        reverseEntities.removeLast()

        pageMasks[pageIdx] &= ~bit
        if pageMasks[pageIdx] == 0 {
            blockMask &= ~(UInt64(1) << pageIdx)
        }
        sparseEntries[sparseIndex].compArrIdx = -1
    }

    @inlinable
    public mutating func get(_ eid: EntityId) -> C? {
        let offset = eid.id & 4095
        let pageIdx = offset >> 6
        let slotIdx = offset & 63
        let bit = UInt64(1) << slotIdx

        guard (pageMasks[pageIdx] & bit) != 0 else { return nil }
        let logicalIdx = Int(sparseEntries[sparseStaggerOffset + Int(offset)].compArrIdx)
        
        // 2. 透過 Pointer 存取 (getRawDataPointer 已經 +stagger 了)
        // 所以 ptr[logicalIdx] = (base + stagger)[0] = base[stagger] -> 正確！
        return getRawDataPointer()[logicalIdx]
    }


    // MARK: - PFStorage 指標介面
    /// 供 ViewPlan 獲取數據陣列指標
    @inlinable
    public mutating func getRawDataPointer() -> UnsafeMutablePointer<C> {
        return components.withUnsafeMutableBufferPointer { $0.baseAddress! + staggerOffset }
    }

    /// 【核心改進】提供連續的 PageMasks 指標，不再需要 PagePtr 逐級查找
    @inlinable
    public func getPageMasksPointer() -> UnsafePointer<UInt64> {
        return pageMasks.withUnsafeBufferPointer { $0.baseAddress! }
    }

    /// 提供連續的 SparseEntries 指標，供快速索引轉換
    @inlinable
    public func getSparseEntriesPointer() -> SSEPtr<C>  {
        return SSEPtr(ptr: sparseEntries.withUnsafeBufferPointer { $0.baseAddress! + sparseStaggerOffset })
    }
}

public struct SSEPtr<C> {
    @usableFromInline
    let ptr: UnsafePointer<SparseSetEntry>
    
    @usableFromInline
    init(ptr: UnsafePointer<SparseSetEntry>) {
        self.ptr = ptr
    }
}