struct PFStorage<T: Component>: ~Copyable {
    private(set) var segments: ContiguousArray<SparseSet_L2<T>?>
    private(set) var activeEntityCount = 0
    private(set) var firstActiveSegment: Int = Int.max
    private(set) var lastActiveSegment: Int = Int.min
    private(set) var activeSegmentCount: Int = 0

    var storageType: any Component.Type { T.self }
    var segmentCount : Int { segments.count }
    
    
    init() {
        self.segments = ContiguousArray<SparseSet_L2<T>?>(repeating: nil, count: 1)
        // self.segments[0] = SparseSet_L2<T>()
    }

    @inline(__always)
    private mutating func ensureCapacity(for eid: EntityId) -> Int {
        let blockIdx = eid.id >> 12

        if blockIdx >= segments.count {
            let needed = blockIdx - segments.count + 1
            segments.append(contentsOf: repeatElement(nil, count: needed))
        }

        if segments[blockIdx] == nil {
            segments[blockIdx] = SparseSet_L2<T>()
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
                if segments[i] != nil {
                    firstActiveSegment = i
                    return
                } 
            }
        }
        else if blockIdx == lastActiveSegment {
            for i in stride(from: lastActiveSegment, through: firstActiveSegment, by: -1) {
                if segments[i] != nil {
                    lastActiveSegment = i
                    return
                }
            }
        }
    }

    @inlinable
    mutating func add(eid: borrowing EntityId, component: consuming T) {
        let blockIdx = ensureCapacity(for: eid) // ensure segments is not nil and return eid's blockId
        let beforeCount = segments[blockIdx]!.count
        segments[blockIdx]!.add(eid, component)
        self.activeEntityCount += (segments[blockIdx]!.count - beforeCount)
    }

    @inlinable
    mutating func remove(eid: borrowing EntityId) {
        let blockIdx = Int(eid.id >> 12)
        guard blockIdx < segments.count, let storage = segments[blockIdx] else { return }
        _ = storage // not nil

        let beforeCount = segments[blockIdx]!.count
        segments[blockIdx]!.remove(eid)
        self.activeEntityCount += (segments[blockIdx]!.count - beforeCount)

        // if segment has no active member
        if segments[blockIdx]!.count == 0 {
            segments[blockIdx] = nil
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
    func getWithDenseIndex_Uncheck_Typed(_ index: Int) -> T? {
        var temp_index = index
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
        {
            if let segment = segments[i] {
                if temp_index >= segment.count {
                    temp_index -= segment.count
                    continue
                }
                // temp_index < segment.count
                return segment.components[temp_index]
            }
        }

        return nil
    }

    @inlinable
    func get(_ eid: borrowing EntityId) -> T? {
        let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
        guard blockIdx < segments.count else { return nil }
        return segments[blockIdx]?.get(offset: offset, version: eid.version)
    }

    @inlinable
    func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        var temp_index = index
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
        {
            if let segment = segments[i] {
                if temp_index >= segment.count {
                    temp_index -= segment.count
                    continue
                }
                // temp_index < segment.count
                return segment.components[temp_index]
            }
        }

        return nil
    }

    @inlinable
    func get(_ eid: borrowing EntityId) -> Any? {
        let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
        guard blockIdx < segments.count else { return nil }
        return segments[blockIdx]?.get(offset: offset, version: eid.version)
    }

    @inlinable
    mutating func rawAdd(eid: borrowing EntityId, component: consuming Any) {
        guard let typedComponent = component as? T else {
            fatalError("the type mismatched while using rawAdd")
        }
        self.add(eid: eid, component: typedComponent)
    }

    @inlinable
    mutating func getRawPointer_Internal(_ blockIdx: Int) -> UnsafeMutablePointer<T> {
        // 這裡使用 Unsafe 存取來繞過 mutating 限制
        // 既然你保證了 reserveCapacity，這是安全的
        return segments[blockIdx]!.getRawDataPointer() 
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

final class PFStorageHandle<T: Component> {
    fileprivate var pfstorage = PFStorage<T>()
}

struct PFStorageBox<T: Component>: AnyPlatformStorage, @unchecked Sendable {
    private let handle: PFStorageHandle<T>
    init(_ h: PFStorageHandle<T>) { self.handle = h}

    @inlinable
    mutating func rawAdd(eid: EntityId, component: Any) {
        handle.pfstorage.rawAdd(eid: eid, component: component)
    }

    @inlinable
    mutating func add(eid: EntityId, component: T) {
        handle.pfstorage.add(eid: eid, component: component)
    }

    @inlinable
    mutating func remove(eid: EntityId) {
        handle.pfstorage.remove(eid: eid)
    }

    @inlinable
    func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        handle.pfstorage.getWithDenseIndex_Uncheck(index)
    }

    @inlinable
    func get(_ eid: EntityId) -> Any? {
        handle.pfstorage.get(eid)
    }

    @inlinable var storageType: any Component.Type { T.self }
    @inlinable var activeEntityCount: Int { handle.pfstorage.activeEntityCount }
    @inlinable var segmentCount : Int { handle.pfstorage.segmentCount }
    @inlinable var firstActiveSegment: Int { handle.pfstorage.firstActiveSegment }
    @inlinable var lastActiveSegment: Int { handle.pfstorage.lastActiveSegment }
    @inlinable var activeSegmentCount: Int { handle.pfstorage.activeSegmentCount }
    
    @inlinable
    func segmentBlockMaskWith(mask: inout UInt64, _ i: Int) {
        if mask == 0 { return }
        if i > handle.pfstorage.lastActiveSegment { mask = UInt64(0); return; } // for more segment
        if let segment = handle.pfstorage.segments[i] {
            segment.block_MaskOut_With(blockMask: &mask)
        } else {
            mask = UInt64(0)
        }
    }

    @inlinable
    func segmentPageMaskWith_Uncheck(mask: inout UInt64, blockIdx: Int, pageIdx: Int) {
        if mask == 0 { return }
        let segment = handle.pfstorage.segments[blockIdx]!
        segment.page_I_MaskOut_With(pageMask: &mask, pageIdx)
    }

    @inlinable
    func get_SparseSetL2_CompMutPointer_Uncheck(_ blockIdx: Int) -> UnsafeMutablePointer<T> {
        handle.pfstorage.getRawPointer_Internal(blockIdx)
    }
    
    @inlinable
    func getSparseSetL2_PagePointer_Uncheck(_ blockIdx: Int) -> PagePtr<T> {
        PagePtr(ptr: handle.pfstorage.segments[blockIdx]!.sparse.getPageRawPointer())
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
    static func createPFStorage() -> any AnyPlatformStorage {
        // 核心修正：使用 Self 而不是 T
        return PFStorageBox<Self>(PFStorageHandle<Self>())
    }
}
