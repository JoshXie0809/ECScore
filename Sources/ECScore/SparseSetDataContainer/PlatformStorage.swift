final class PFStorage<T: Component>: AnyPlatformStorage {
    private(set) var segments: ContiguousArray<SparseSet_L2<T>?>
    var storageType: any Component.Type { T.self }

    init() {
        self.segments = ContiguousArray<SparseSet_L2<T>?>(repeating: nil, count: 1)
        self.segments[0] = SparseSet_L2<T>()
    }

    @inlinable
    func ensureCapacity(for eid: EntityId) {
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
    func add(eid: EntityId, component: T) {
        ensureCapacity(for: eid) // ensure segments is not nil
        let blockIdx = eid.id >> 12

        segments[blockIdx]!.add(eid, component)
    }

    @inlinable
    func remove(eid: EntityId) {
        let blockIdx = Int(eid.id >> 12)
        guard blockIdx < segments.count, let storage = segments[blockIdx] else { return }
        _ = storage // not nil

        segments[blockIdx]!.remove(eid)
        
        // 選配優化：如果該 L2 完全空了，可以釋放掉來省記憶體
        if segments[blockIdx]!.sparse.activeEntityCount == 0 {
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
    func rawAdd(eid: EntityId, component: Any) {
        guard let typedComponent = component as? T else {
            fatalError("the type mismatched while using rawAdd")
        }
        self.add(eid: eid, component: typedComponent)
    }
}

extension PFStorage: Component where T: Component {
    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<Self>()
    }
}

// 定義一個協議，用來獲取內部泛型 T 的類型
protocol StorageTypeProvider {
    /// 告訴外界，這個 Storage 裡面管理的 Component 型別是什麼
    var storedComponentType: any Component.Type { get }
}

extension PFStorage: StorageTypeProvider {
    var storedComponentType: any Component.Type {
        return T.self // 直接回傳泛型 T 的型別
    }
}