struct PFStorage<T: Component>: ~Copyable {
    private(set) var segments: ContiguousArray<SparseSet_L2<T>?>
    private(set) var activeEntityCount = 0
    private(set) var firstActiveSegment: Int = Int.max
    private(set) var lastActiveSegment: Int = Int.min
    
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
        }

        updateFirstLast_Add(blockIdx: blockIdx)
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

            if activeEntityCount == 0 {
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
        for segment: SparseSet_L2<T>? in segments {
            if (segment == nil) { continue }
            if temp_index >= segment!.count {
                temp_index -= segment!.count
                continue
            }
            // temp_index < segment.count
            return segment!.components[temp_index]
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
        for segment: SparseSet_L2<T>? in segments {
            if (segment == nil) { continue }
            if temp_index >= segment!.count {
                temp_index -= segment!.count
                continue
            }
            // temp_index < segment.count
            return segment!.components[temp_index]
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

struct PFStorageBox<T: Component>: AnyPlatformStorage {
    private let handle: PFStorageHandle<T>
    init(_ h: PFStorageHandle<T>) { self.handle = h}

    mutating func rawAdd(eid: EntityId, component: Any) {
        handle.pfstorage.rawAdd(eid: eid, component: component)
    }

    mutating func add(eid: EntityId, component: T) {
        handle.pfstorage.add(eid: eid, component: component)
    }

    mutating func remove(eid: EntityId) {
        handle.pfstorage.remove(eid: eid)
    }

    func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        handle.pfstorage.getWithDenseIndex_Uncheck(index)
    }

    func get(_ eid: EntityId) -> Any? {
        handle.pfstorage.get(eid)
    }

    var storageType: any Component.Type { T.self }
    var activeEntityCount: Int { handle.pfstorage.activeEntityCount }
    var segmentCount : Int { handle.pfstorage.segmentCount }

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
            // 在這裡可以加入讀取鎖的邏輯，或者配合系統的 Phase 檢查
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
