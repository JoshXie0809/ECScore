protocol SparseSet {
    mutating func remove(_ eid: EntityId)
}

// 0x0FFF = 4096-1

struct SparseSet_L2<T: Component>: SparseSet {
    private(set) var sparse: Block64_L2
    private(set) var components : ContiguousArray<T>
    private(set) var reverseEntities: ContiguousArray<BlockId>

    @inlinable
    var count : Int {
        components.count
    }

    init() {
        self.components = ContiguousArray<T>()
        self.components.reserveCapacity(4096)
        self.sparse = Block64_L2()
        self.reverseEntities = ContiguousArray<BlockId>()
        self.reverseEntities.reserveCapacity(4096)
    }

    @inlinable
    mutating func remove(_ eid: EntityId) {
        let version = eid.version
        let offset = eid.id & 0x0FFF // 4095
        guard sparse.contains(offset) else { return }
        
        let entry = sparse.getUnchecked(offset)
        let removeIdx = Int(entry.compArrIdx)

        // check version matched
        precondition( 
            reverseEntities[removeIdx].version == version, 
            "\(T.self): the version of entity not matched while removing \(eid.id)" 
        )

        // remove sparse let in scared of other threads not errorly read
        sparse.removeEntityOnBlock(offset) // total count -= 1

        // swap and pop
        let lastIdx = sparse.activeEntityCount // count is -1 while removing sparse
        
        if removeIdx < lastIdx {
            let lastBlockId = reverseEntities[lastIdx]
            // update 3 places
            components[removeIdx] = components[lastIdx]
            reverseEntities[removeIdx] = lastBlockId
            sparse.updateComponentArrayIdx( Int(lastBlockId.offset) ) { ssEntry in
                ssEntry.compArrIdx = Int16(removeIdx)              
            }
        }

        // remove 3 places
        components.removeLast()
        reverseEntities.removeLast()
        // sparse is remove before
    }

    @inlinable
    mutating func add(_ eid: EntityId, _ component: T) {
        let version = eid.version
        let offset = eid.id & 0x0FFF
        guard !sparse.contains(offset) else { return }
        
        // here not contain eid
        let ssEntry = SparseSetEntry(compArrIdx: Int16(components.count))
        let bId = BlockId(offset: Int16(offset), version: version)

        self.components.append(component)
        self.reverseEntities.append(bId)
        sparse.addEntityOnBlock(offset, ssEntry: ssEntry)

    }

    @inlinable 
    func get(offset: Int, version: Int) -> T? {        
        guard sparse.contains(offset) else {
            return nil
        }

        let idx = Int(sparse.getUnchecked(offset).compArrIdx)
        guard reverseEntities[idx].version == version else {
            return nil
        }
        
        return components[idx]
    }

    @inlinable
    func getUnchecked(offset: Int) -> T {
        let entry = sparse.getUnchecked(offset)
        return components[Int(entry.compArrIdx)]
    }

    @inlinable
    func getWithDenseIndex_Uncheck(denseIdx: Int) -> T {
        // not check
        components[denseIdx]
    }

    @inlinable
    func getWithDenseIndex(denseIdx: Int) -> T? {
        guard denseIdx < components.count else {
            return nil
        }

        return components[denseIdx]
    }

    @inlinable
    mutating func updateWithDenseIndex_Uncheck(denseIdx: Int, _ action: (inout T) -> Void) {
        // 這裡同樣建議用 inout 以保持結構的 In-place 性能
        action(&components[denseIdx])
    }
}
