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

    mutating func remove(_ eid: EntityId) {
        let version = eid.version
        let offset = eid.id & 0x0FFF
        guard sparse.contains(offset) else { return }
        
        let entry = sparse.getUnchecked(offset)
        let componentsIdxOfEntity = Int(entry.compArrIdx)

        // check version matched
        precondition( 
            reverseEntities[componentsIdxOfEntity].version == version, 
            "\(T.self): the version of entity not matched while removing \(eid.id)" 
        )

        

        // let blockId = BlockId(offset: Int16(offset), version: version)

        // sparse.removeEntityOnBlock(Int, ssEntry: SparseSetEntry)
    }


}