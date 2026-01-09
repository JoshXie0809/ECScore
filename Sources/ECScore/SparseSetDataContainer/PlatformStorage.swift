final class PFStorage<T: Component>: AnyPlatformStorage {
    private(set) var segments: ContiguousArray<SparseSet_L2<T>?>

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

    func rawAdd(eid: EntityId, component: Any) {
        guard let typedComponent = component as? T else {
            print("Warning: Type mismatch in storage")
            return
        }
        self.add(eid: eid, component: typedComponent)
    }
}