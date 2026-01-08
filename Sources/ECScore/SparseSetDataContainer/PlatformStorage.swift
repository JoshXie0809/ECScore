
struct PFStorage<T: Component>: PlatformStorage {
    private(set) var segments: ContiguousArray<SparseSet_L2<T>?>

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

        segments[blockIdx]!.add(eid, component)
    }

    @inlinable
    mutating func remove(eid: EntityId) {
        let blockIdx = Int(eid.id >> 12)
        guard blockIdx < segments.count, let storage = segments[blockIdx] else { return }
        _ = storage // not nil

        segments[blockIdx]!.remove(eid)
        
        // 選配優化：如果該 L2 完全空了，可以釋放掉來省記憶體
        if segments[blockIdx]!.sparse.activeEntityCount == 0 {
            segments[blockIdx] = nil
        }
    }

}