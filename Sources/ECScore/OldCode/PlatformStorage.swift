// struct PFStorage2<T: Component>: ~Copyable {
//     private(set) var segments: ContiguousArray<SparseSet_L2<T>?>
//     private(set) var activeEntityCount = 0
//     private(set) var firstActiveSegment: Int = Int.max
//     private(set) var lastActiveSegment: Int = Int.min
//     private(set) var activeSegmentCount: Int = 0

//     private let sentinelPtr: UnsafeMutablePointer<SparseSet_L2<T>>

//     var storageType: any Component.Type { T.self }
//     var segmentCount : Int { segments.count }
    
//     init() {
//         self.sentinelPtr = UnsafeMutablePointer<SparseSet_L2<T>>.allocate(capacity: 1)
//         self.sentinelPtr.initialize(to: SparseSet_L2<T>()) // 初始化為空的 SparseSet        
//         self.segments = ContiguousArray<SparseSet_L2<T>?>(repeating: nil, count: 1)
//     }

//     @inline(__always)
//     private mutating func ensureCapacity(for eid: EntityId) -> Int {
//         let blockIdx = eid.id >> 12

//         if blockIdx >= segments.count {
//             let needed = blockIdx - segments.count + 1
//             segments.append(contentsOf: repeatElement(nil, count: needed))
//         }

//         if segments[blockIdx] == nil {
//             segments[blockIdx] = SparseSet_L2<T>()
//             activeSegmentCount += 1
//             updateFirstLast_Add(blockIdx: blockIdx)
//         }

//         return blockIdx
//     }

//     @inline(__always)
//     private mutating func updateFirstLast_Add(blockIdx: Int) {
//         firstActiveSegment = min(firstActiveSegment, blockIdx)
//         lastActiveSegment = max(lastActiveSegment, blockIdx)
//     }

//     @inline(__always)
//     private mutating func updateFirstLast_Remove(blockIdx: Int) {
//         if blockIdx == firstActiveSegment {
//             for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1){
//                 if segments[i] != nil {
//                     firstActiveSegment = i
//                     return
//                 } 
//             }
//         }
//         else if blockIdx == lastActiveSegment {
//             for i in stride(from: lastActiveSegment, through: firstActiveSegment, by: -1) {
//                 if segments[i] != nil {
//                     lastActiveSegment = i
//                     return
//                 }
//             }
//         }
//     }

//     @inlinable
//     mutating func add(eid: borrowing EntityId, component: consuming T) {
//         let blockIdx = ensureCapacity(for: eid) // ensure segments is not nil and return eid's blockId
//         let beforeCount = segments[blockIdx]!.count
//         segments[blockIdx]!.add(eid, component)
//         self.activeEntityCount += (segments[blockIdx]!.count - beforeCount)
//     }

//     @inlinable
//     mutating func remove(eid: borrowing EntityId) {
//         let blockIdx = Int(eid.id >> 12)
//         guard blockIdx < segments.count, let storage = segments[blockIdx] else { return }
//         _ = storage // not nil

//         let beforeCount = segments[blockIdx]!.count
//         segments[blockIdx]!.remove(eid)
//         self.activeEntityCount += (segments[blockIdx]!.count - beforeCount)

//         // if segment has no active member
//         if segments[blockIdx]!.count == 0 {
//             segments[blockIdx] = nil
//             activeSegmentCount -= 1

//             if activeSegmentCount == 0 {
//                 firstActiveSegment = Int.max
//                 lastActiveSegment = Int.min
//             } else {
//                 updateFirstLast_Remove(blockIdx: blockIdx)
//             }
//         }
//     }

//     @inlinable
//     func getWithDenseIndex_Uncheck_Typed(_ index: Int) -> T? {
//         var temp_index = index
//         for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
//         {
//             if let segment = segments[i] {
//                 if temp_index >= segment.count {
//                     temp_index -= segment.count
//                     continue
//                 }
//                 // temp_index < segment.count
//                 return segment.components[temp_index]
//             }
//         }

//         return nil
//     }

//     @inlinable
//     func get(_ eid: borrowing EntityId) -> T? {
//         let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
//         guard blockIdx < segments.count else { return nil }
//         return segments[blockIdx]?.get(offset: offset, version: eid.version)
//     }

//     @inlinable
//     func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
//         var temp_index = index
//         for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
//         {
//             if let segment = segments[i] {
//                 if temp_index >= segment.count {
//                     temp_index -= segment.count
//                     continue
//                 }
//                 // temp_index < segment.count
//                 return segment.components[temp_index]
//             }
//         }

//         return nil
//     }

//     @inlinable
//     func get(_ eid: borrowing EntityId) -> Any? {
//         let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
//         guard blockIdx < segments.count else { return nil }
//         return segments[blockIdx]?.get(offset: offset, version: eid.version)
//     }

//     @inlinable
//     mutating func rawAdd(eid: borrowing EntityId, component: consuming Any) {
//         guard let typedComponent = component as? T else {
//             fatalError("the type mismatched while using rawAdd")
//         }
//         self.add(eid: eid, component: typedComponent)
//     }

//     @inlinable
//     mutating func getSegmentComponentsRawPointer_Internal(_ blockIdx: Int) -> UnsafeMutablePointer<T> {
//         // 這裡使用 Unsafe 存取來繞過 mutating 限制
//         // 既然你保證了 reserveCapacity，這是安全的
//         return segments[blockIdx]!.getRawDataPointer() 
//     }

//     @inlinable
//     func getSegmentsRawPointer_Internal() -> UnsafePointer<SparseSet_L2<T>?> {
//         return segments.withUnsafeBufferPointer { $0.baseAddress! }    
//     }
// }
