// struct SparseSet_L2<T: Component> {
//     private(set) var sparse: Block64_L2
//     private(set) var components : ContiguousArray<T>
//     private(set) var reverseEntities: ContiguousArray<BlockId>

//     @inlinable
//     var count : Int {
//         components.count
//     }

//     init() {
//         self.components = ContiguousArray<T>()
//         self.components.reserveCapacity(4096 + HardwareBufferPadding)
//         self.sparse = Block64_L2()
//         self.reverseEntities = ContiguousArray<BlockId>()
//         self.reverseEntities.reserveCapacity(4096 + HardwareBufferPadding)
//     }

//     @inlinable
//     mutating func remove(_ eid: EntityId) {
//         let offset = eid.id & 0x0FFF // 4095
//         guard sparse.contains(offset) else { return }
        
//         let entry = sparse.getUnchecked(offset)
//         let removeIdx = Int(entry.compArrIdx)

//         // check version matched
//         // version is now manage by EntityPlatform
//         // precondition( 
//         //     reverseEntities[removeIdx].version == version, 
//         //     "\(T.self): the version of entity not matched while removing \(eid.id)" 
//         // )

//         // remove sparse let in scared of other threads not errorly read
//         sparse.removeEntityOnBlock(offset) // total count -= 1

//         // swap and pop
//         let lastIdx = sparse.activeEntityCount // count is -1 while removing sparse
        
//         if removeIdx < lastIdx {
//             let lastBlockId = reverseEntities[lastIdx]
//             // update 3 places
//             components[removeIdx] = components[lastIdx]
//             reverseEntities[removeIdx] = lastBlockId
//             sparse.updateComponentArrayIdx( Int(lastBlockId.offset) ) { ssEntry in
//                 ssEntry.compArrIdx = Int16(removeIdx)              
//             }
//         }

//         // remove 3 places
//         components.removeLast()
//         reverseEntities.removeLast()
//         // sparse is remove before
//     }

//     @inlinable
//     mutating func add(_ eid: EntityId, _ component: T) {
//         // let version = eid.version
//         let offset = eid.id & 0x0FFF
//         guard !sparse.contains(offset) else { return }
        
//         // here not contain eid
//         let ssEntry = SparseSetEntry(compArrIdx: Int16(components.count))
//         let bId = BlockId(offset: Int16(offset))

//         self.components.append(component)
//         self.reverseEntities.append(bId)
//         sparse.addEntityOnBlock(offset, ssEntry: ssEntry)
//     }

//     @inlinable 
//     func get(offset: Int, version: Int) -> T? {        
//         guard sparse.contains(offset) else {
//             return nil
//         }

//         let idx = Int(sparse.getUnchecked(offset).compArrIdx)
//         // guard reverseEntities[idx].version == version else {
//         //     return nil
//         // }
        
//         return components[idx]
//     }

//     @inlinable
//     func getUnchecked(offset: Int) -> T {
//         let entry = sparse.getUnchecked(offset)
//         return components[Int(entry.compArrIdx)]
//     }

//     @inlinable
//     func getWithDenseIndex_Uncheck(denseIdx: Int) -> T {
//         // not check
//         components[denseIdx]
//     }

//     @inlinable
//     func getWithDenseIndex(denseIdx: Int) -> T? {
//         guard denseIdx < components.count else {
//             return nil
//         }

//         return components[denseIdx]
//     }

//     @inlinable
//     mutating func updateWithDenseIndex_Uncheck(denseIdx: Int, _ action: (inout T) -> Void) {
//         // 這裡同樣建議用 inout 以保持結構的 In-place 性能
//         action(&components[denseIdx])
//     }

//     // 改成 mutating func
//     @inlinable
//     mutating func getRawDataPointer() -> UnsafeMutablePointer<T> {
//         return components.withUnsafeMutableBufferPointer { $0.baseAddress! }
//     }   
// }

// extension Block64_L2 {
//     // 獲取 Page 陣列的原始指標
//     @inlinable
//     @inline(__always)
//     func getPageRawPointer() -> UnsafePointer<Page64> {
//         // ContiguousArray 保證記憶體連續性，直接獲取基底地址
//         return pageOnBlock.withUnsafeBufferPointer { $0.baseAddress! }
//     }
// }

@usableFromInline
struct PagePtr<T> {
    @usableFromInline
    @inline(__always)
    let ptr: UnsafePointer<UInt64>

    @usableFromInline
    @inline(__always)
    init(ptr: UnsafePointer<UInt64>) {
        self.ptr = ptr
    }

    // @inline(__always)
    // func getEntityOnPagePointer_Uncheck(_ pageIdx: Int) -> EntityOnPagePtr<T> {
    //     EntityOnPagePtr(ptr: ptr.advanced(by: pageIdx).pointee.entityOnPage.withUnsafeBufferPointer { $0.baseAddress! } )
    // }
}

// extension Page64 {
//     // 獲取 Page 陣列的原始指標
//     @inlinable
//     @inline(__always)
//     func getEntityOnPageRawPointer() -> UnsafePointer<SparseSetEntry> {
//         // ContiguousArray 保證記憶體連續性，直接獲取基底地址
//         return (entityOnPage.withUnsafeBufferPointer { $0.baseAddress! })
//     }
// }

// struct EntityOnPagePtr<T> {
//     let ptr: UnsafePointer<SparseSetEntry>
//     @inlinable
//     func getSlotCompArrIdx_Uncheck(_ slotIdx: Int) -> Int {
//         return Int(ptr.advanced(by: slotIdx).pointee.compArrIdx)
//     }
// }

// struct SentinelContainer<T: Component>: @unchecked Sendable {
//     let ptr: UnsafeMutablePointer<SparseSet_L2<T>>
    
//     init() {
//         // 這裡分配記憶體，保證地址永久固定
//         ptr = UnsafeMutablePointer<SparseSet_L2<T>>.allocate(capacity: 1)
//         // 初始化為空的 SparseSet
//         ptr.initialize(to: SparseSet_L2<T>())
//     }
// }
