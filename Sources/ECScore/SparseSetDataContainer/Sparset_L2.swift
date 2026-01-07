protocol SparseSet {
    mutating func remove(_ eid: EntityId)
}

// 0x0FFF = 4096-1

struct SparseSet_L2<T: Component>: SparseSet {
    private(set) var sparse: Block64_L2
    private(set) var components : ContiguousArray<T>
    private(set) var reverseEntities: ContiguousArray<BlockId>

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
        let offset = eid.id & 0x0FFF
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
}