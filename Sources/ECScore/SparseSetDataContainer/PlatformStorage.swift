struct PFStorage<T: Component>: ~Copyable {
    private(set) var segments: ContiguousArray<SparseSet_L2<T>?>
    private(set) var activeEntityCount = 0
    var storageType: any Component.Type { T.self }

    init() {
        self.segments = ContiguousArray<SparseSet_L2<T>?>(repeating: nil, count: 1)
        self.segments[0] = SparseSet_L2<T>()
    }

    @inlinable
    mutating func ensureCapacity(for eid: EntityId) {
        let blockIdx = eid.id >> 12

        if blockIdx >= segments.count {
            let needed = blockIdx - segments.count + 1
            segments.append(contentsOf: repeatElement(nil, count: needed))
        }

        if segments[blockIdx] == nil {
            segments[blockIdx] = SparseSet_L2<T>()
        }
    }

    @inlinable
    mutating func add(eid: EntityId, component: T) {
        ensureCapacity(for: eid) // ensure segments is not nil
        let blockIdx = eid.id >> 12
        
        let beforeCount = segments[blockIdx]!.count
        segments[blockIdx]!.add(eid, component)
        self.activeEntityCount += (segments[blockIdx]!.count - beforeCount)
    }

    @inlinable
    mutating func remove(eid: EntityId) {
        let blockIdx = Int(eid.id >> 12)
        guard blockIdx < segments.count, let storage = segments[blockIdx] else { return }
        _ = storage // not nil

        let beforeCount = segments[blockIdx]!.count
        segments[blockIdx]!.remove(eid)
        self.activeEntityCount += (segments[blockIdx]!.count - beforeCount)

        // if segment has no active member
        if segments[blockIdx]!.count == 0 {
            segments[blockIdx] = nil
        }
    }

    @inlinable
    func getWithDenseIndex_Uncheck<U: Component>(_ index: Int) -> U? {
        var temp_index = index
        for segment: SparseSet_L2<T>? in segments {
            if (segment == nil) { continue }
            if temp_index >= segment!.count {
                temp_index -= segment!.count
                continue
            }
            // temp_index < segment.count
            return segment!.components[temp_index] as? U
        }

        return nil
    }

    @inlinable
    func get<U: Component>(_ eid: EntityId) -> U? {
        let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
        return segments[blockIdx]?.get(offset: offset) as? U
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
    func get(_ eid: EntityId) -> Any? {
        let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
        return segments[blockIdx]?.get(offset: offset)
    }

    @inlinable
    mutating func rawAdd(eid: EntityId, component: Any) {
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