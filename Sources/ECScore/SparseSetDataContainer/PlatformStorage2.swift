public protocol AnySparseSet {
    associatedtype T where T: Component
    init()
    var count: Int { get }
    var blockMask: UInt64 { get }
    var pageMasks: ContiguousArray<UInt64> { get }
    mutating func add(_ eid: EntityId, _ component: consuming T)
    mutating func remove(_ eid: EntityId)
    func get(_ eid: EntityId) -> T?
    func getPageMasksPointer() -> UnsafePointer<UInt64>
}

public protocol DenseSparseSet: AnySparseSet {
    mutating func getRawDataPointer() -> UnsafeMutablePointer<T>
    func getSparseEntriesPointer() -> SSEPtr<T>
    func getReverseEntitiesPointer() -> UnsafePointer<BlockId>
}

struct PFStorage<T: Component>: ~Copyable {
    // this is not nill version
    private(set) var segments: ContiguousArray<UnsafeMutablePointer< T.SparseSetType >>
    
    private(set) var activeEntityCount = 0
    private(set) var firstActiveSegment: Int = Int.max
    private(set) var lastActiveSegment: Int = Int.min
    private(set) var activeSegmentCount: Int = 0

    public let sentinelPtr: UnsafeMutablePointer< T.SparseSetType >

    var storageType: any Component.Type { T.self }
    var segmentCount : Int { segments.count }
    
    init() {
        self.sentinelPtr = UnsafeMutablePointer< T.SparseSetType >.allocate(capacity: 1)
        self.sentinelPtr.initialize(to: T.createSparseSet())   
        self.segments = ContiguousArray()
        self.segments.reserveCapacity(1024) // init some place
    }

    deinit {
        for ptr in segments {
            // de-init not nil page
            if ptr != sentinelPtr {
                ptr.deinitialize(count: 1)
                ptr.deallocate()
            }
        }

        sentinelPtr.deinitialize(count: 1)
        sentinelPtr.deallocate()
    }

    @inline(__always)
    private func allocatePage() -> UnsafeMutablePointer<T.SparseSetType> {
        let ptr = UnsafeMutablePointer<T.SparseSetType>.allocate(capacity: 1)
        ptr.initialize(to: T.createSparseSet())
        return ptr
    }

    // 輔助：釋放 Page
    @inline(__always)
    private func freePage(_ ptr: UnsafeMutablePointer<T.SparseSetType>) {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    @inline(__always)
    private mutating func ensureCapacity(for eid: EntityId) -> Int {
        let blockIdx = Int(eid.id >> 12)
        if blockIdx >= segments.count {
            let needed = blockIdx - segments.count + 1
            segments.append(contentsOf: repeatElement(sentinelPtr, count: needed))
        }

        if segments[blockIdx] == sentinelPtr {
            segments[blockIdx] = allocatePage()
            activeSegmentCount += 1
            updateFirstLast_Add(blockIdx: blockIdx)
        }

        return blockIdx
    }

    @inline(__always)
    private mutating func updateFirstLast_Add(blockIdx: Int) {
        firstActiveSegment = min(firstActiveSegment, blockIdx)
        lastActiveSegment = max(lastActiveSegment, blockIdx)
    }

    @inline(__always)
    private mutating func updateFirstLast_Remove(blockIdx: Int) {
        if blockIdx == firstActiveSegment {
            for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1){
                if segments[i] != sentinelPtr {
                    firstActiveSegment = i
                    return
                } 
            }

            firstActiveSegment = Int.max
            lastActiveSegment = Int.min
        }
        else if blockIdx == lastActiveSegment {
            for i in stride(from: lastActiveSegment, through: firstActiveSegment, by: -1) {
                if segments[i] != sentinelPtr {
                    lastActiveSegment = i
                    return
                }
            }

            firstActiveSegment = Int.max
            lastActiveSegment = Int.min
        }
    }

    @inlinable
    @inline(__always)
    mutating func add(eid: borrowing EntityId, component: consuming T) {
        let blockIdx = ensureCapacity(for: eid)

        assert(segments[blockIdx] != sentinelPtr, "using sentinelPtr in PFStorage.add") // for-debug
        let storagePtr = segments[blockIdx]
        
        let beforeCount = storagePtr.pointee.count
        storagePtr.pointee.add(eid, component)
        self.activeEntityCount += (storagePtr.pointee.count - beforeCount)
    }
    

    @inlinable
    @inline(__always)
    mutating func remove(eid: borrowing EntityId) {
        let blockIdx = Int(eid.id >> 12)
        
        guard blockIdx < segments.count else { return }
        let storagePtr = segments[blockIdx]
        guard storagePtr != sentinelPtr else { return }

        let beforeCount = storagePtr.pointee.count
        storagePtr.pointee.remove(eid)
        self.activeEntityCount += (storagePtr.pointee.count - beforeCount)

        // if segment has no active member
        if storagePtr.pointee.count == 0 {
            freePage(segments[blockIdx])
            // set as sentinel
            segments[blockIdx] = sentinelPtr
            activeSegmentCount -= 1

            if activeSegmentCount == 0 {
                firstActiveSegment = Int.max
                lastActiveSegment = Int.min
            } else {
                updateFirstLast_Remove(blockIdx: blockIdx)
            }
        }
    }

    @inlinable
    @inline(__always)
    mutating func removeAll() {
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) {
            if segments[i] == sentinelPtr { continue }
            freePage(segments[i])
            segments[i] = sentinelPtr
        }

        activeEntityCount = 0
        firstActiveSegment = Int.max
        lastActiveSegment = Int.min
        activeSegmentCount = 0
    }

    @inlinable
    @inline(__always)
    func getWithDenseIndex_Uncheck_Typed(_ index: Int) -> T? {
        guard T.SparseSetType.self == SparseSet_L2_2<T>.self else { return nil }
        var temp_index = index
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
        {
            let segmentPtr = segments[i] as! UnsafeMutablePointer<SparseSet_L2_2<T>>
            if segmentPtr != sentinelPtr {
                let count = segmentPtr.pointee.count
                if temp_index >= count {
                    temp_index -= count
                    continue
                }
                
                return segmentPtr.pointee.getRawDataPointer()[temp_index]
            }
        }

        return nil
    }

    @inlinable
    @inline(__always)
    func get(_ eid: borrowing EntityId) -> T? {
        let blockIdx = Int(eid.id >> 12)
        guard blockIdx < segments.count else { return nil }
        let ptr = segments[blockIdx]
        if ptr == sentinelPtr { return nil }
        
        // 直接調用 SparseSet 內部的 get，它會處理 Sparse -> Dense 的轉換
        return ptr.pointee.get(eid)
    }

    @inlinable
    @inline(__always)
    func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        guard T.SparseSetType.self == SparseSet_L2_2<T>.self else { return nil }
        var temp_index = index
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
        {
            let segmentPtr = segments[i] as! UnsafeMutablePointer<SparseSet_L2_2<T>>
            if segmentPtr != sentinelPtr {
                let count = segmentPtr.pointee.count
                if temp_index >= count {
                    temp_index -= count
                    continue
                }
                return segmentPtr.pointee.getRawDataPointer()[temp_index]            
            }
        }
        return nil
    }
    
    @inlinable
    @inline(__always)
    func get(_ eid: borrowing EntityId) -> Any? {
        let blockIdx = eid.id >> 12
        guard blockIdx < segments.count else { return nil }
        let segmentPtr = segments[blockIdx]
        guard segmentPtr != sentinelPtr else {
            return nil
        }
        
        return segmentPtr.pointee.get(eid)
    }


    @inlinable
    @inline(__always)
    mutating func rawAdd(eid: borrowing EntityId, component: consuming Any) {
        guard let typedComponent = component as? T else {
            fatalError("the type mismatched while using rawAdd")
        }
        self.add(eid: eid, component: typedComponent)
    }

    @inlinable
    @inline(__always)
    mutating func getSegmentComponentsRawPointer_Internal(_ blockIdx: Int) -> UnsafeMutablePointer<T> where T.SparseSetType: DenseSparseSet {
        // 這裡使用 Unsafe 存取來繞過 mutating 限制
        // 既然你保證了 reserveCapacity，這是安全的
        // 直接回傳，呼叫者需確保該 Segment 有效
        return segments[blockIdx].pointee.getRawDataPointer()
    }

    @inlinable
    @inline(__always)
    func getSegmentReverseEntitiesRawPointer_Internal(_ blockIdx: Int) -> UnsafePointer<BlockId> where T.SparseSetType: DenseSparseSet {
        return segments[blockIdx].pointee.getReverseEntitiesPointer()
    }

    @inlinable
    @inline(__always)
    func getSegmentsRawPointer_Internal() -> UnsafePointer<UnsafeMutablePointer<T.SparseSetType>> {
        // 【核心優化成果】
        // 現在這裡回傳的是「指標的陣列」，而不是「Optional 的陣列」
        // 在 C 語言層面，這就是 T** (pointer to pointer)
        // 這是最適合 createViewPlans 進行無分支讀取的格式
        return segments.withUnsafeBufferPointer { $0.baseAddress! }
    }
}


// 定義一個協議，用來獲取內部泛型 T 的類型
protocol StorageTypeProvider: ~Copyable {
    /// 告訴外界，這個 Storage 裡面管理的 Component 型別是什麼
    var storedComponentType: any Component.Type { get }
}

extension PFStorage: StorageTypeProvider {
    var storedComponentType: any Component.Type {
        return T.self // 直接回傳泛型 T 的型別
    }
}

public final class PFStorageHandle<T: Component> {
    @inline(__always)
    fileprivate(set) var pfstorage = PFStorage<T>()
}

public struct PFStorageBox<T: Component>: AnyPlatformStorage, @unchecked Sendable {
    @inline(__always)
    private let handle: PFStorageHandle<T>
    @inline(__always)
    public init(_ h: PFStorageHandle<T>) { self.handle = h}

    @inline(__always)    
    public mutating func rawAdd(eid: EntityId, component: Any) {
        handle.pfstorage.rawAdd(eid: eid, component: component)
    }

    @inline(__always)
    public mutating func add(eid: EntityId, component: T) {
        handle.pfstorage.add(eid: eid, component: component)
    }

    @inline(__always)
    public mutating func remove(eid: EntityId) {
        handle.pfstorage.remove(eid: eid)
    }

    @inline(__always)
    public mutating func removeAll() {
        handle.pfstorage.removeAll()
    }

    @inline(__always)
    public func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        handle.pfstorage.getWithDenseIndex_Uncheck(index)
    }

    @inline(__always)
    public func get(_ eid: EntityId) -> Any? {
        handle.pfstorage.get(eid)
    }

    @inline(__always) public var storageType: any Component.Type { T.self }
    @inline(__always) public var activeEntityCount: Int { handle.pfstorage.activeEntityCount }
    @inline(__always) var segmentCount : Int { handle.pfstorage.segmentCount }
    @inline(__always) var firstActiveSegment: Int { handle.pfstorage.firstActiveSegment }
    @inline(__always) var lastActiveSegment: Int { handle.pfstorage.lastActiveSegment }
    @inline(__always) var activeSegmentCount: Int { handle.pfstorage.activeSegmentCount }
    
    // @inlinable
    // func segmentBlockMaskWith(mask: inout UInt64, _ i: Int) {
    //     if mask == 0 { return }
    //     if i > handle.pfstorage.lastActiveSegment { mask = UInt64(0); return; } // for more segment
    //     if let segment = handle.pfstorage.segments[i] {
    //         segment.block_MaskOut_With(blockMask: &mask)
    //     } else {
    //         mask = UInt64(0)
    //     }
    // }

    // @inlinable
    // func segmentPageMaskWith_Uncheck(mask: inout UInt64, blockIdx: Int, pageIdx: Int) {
    //     if mask == 0 { return }
    //     let segment = handle.pfstorage.segments[blockIdx]!
    //     segment.page_I_MaskOut_With(pageMask: &mask, pageIdx)
    // }

    @usableFromInline
    @inline(__always)
    func get_SparseSetL2_CompMutPointer_Uncheck(_ blockIdx: Int) -> UnsafeMutablePointer<T> where T.SparseSetType: DenseSparseSet {
        handle.pfstorage.getSegmentComponentsRawPointer_Internal(blockIdx)
    }
    
    @usableFromInline
    @inline(__always)
    func get_SparseSetL2_PagePointer_Uncheck(_ blockIdx: Int) -> PagePtr<T> {
        PagePtr(ptr: handle.pfstorage.segments[blockIdx].pointee.getPageMasksPointer())
    }

    @usableFromInline
    @inline(__always)
    func get_SparseSetL2_ReversePointer_Uncheck(_ blockIdx: Int) -> UnsafePointer<BlockId> where T.SparseSetType: DenseSparseSet {
        handle.pfstorage.getSegmentReverseEntitiesRawPointer_Internal(blockIdx)
    }

    @usableFromInline
    @inline(__always)
    func get_SparseSetL2_Count_Uncheck(_ blockIdx: Int) -> Int {
        handle.pfstorage.segments[blockIdx].pointee.count
    }

    @usableFromInline
    @inline(__always)
    func get_SparseSetL2_PagePointer(_ blockIdx: Int) -> PagePtr<T> {
        let ptr = blockIdx < handle.pfstorage.segmentCount ?
              PagePtr<T>(ptr: handle.pfstorage.segments[blockIdx].pointee.getPageMasksPointer())
            : PagePtr<T>(ptr: handle.pfstorage.sentinelPtr.pointee.getPageMasksPointer()) 

        return ptr
    }

    @usableFromInline
    @inline(__always)
    var segments: UnsafePointer<UnsafeMutablePointer<T.SparseSetType>> {
        handle.pfstorage.getSegmentsRawPointer_Internal()
    }

    @inline(__always)
    func isActiveSegment(_ blockIdx: Int) -> Bool {
        if blockIdx < 0 || blockIdx >= handle.pfstorage.segments.count { return false }
        return handle.pfstorage.segments[blockIdx] != handle.pfstorage.sentinelPtr
    }

    var view: PFStorageView<T> {
        PFStorageView(handle)
    }
}

struct PFStorageView<T: Component>: @unchecked Sendable, ~Copyable {
    private let handle: PFStorageHandle<T>

    init(_ handle: PFStorageHandle<T>) {
        self.handle = handle
    }

    @inlinable
    var storage: PFStorage<T> {
        _read {
            yield handle.pfstorage
        }
    }
}

extension PFStorageBox: Component where T: Component {
    public init() { self.handle = PFStorageHandle<T>()}
    
    public static func createPFSBox() -> any AnyPlatformStorage {
        return PFStorageBox<Self>(PFStorageHandle<Self>())
    }
}
