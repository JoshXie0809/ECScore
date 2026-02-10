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

public final class PFStorageHandle<T: Component> {
    @inline(__always)
    fileprivate(set) var pfstorage = PFStorage<T>()
}

public struct PFStorageBox<T: Component>: AnyPlatformStorage, @unchecked Sendable {
    @inline(__always)
    private let handle: PFStorageHandle<T>
    @inline(__always)
    public init(_ h: PFStorageHandle<T>) { self.handle = h}

    @inline(__always)    
    public mutating func rawAdd(eid: EntityId, component: Any) {
        handle.pfstorage.rawAdd(eid: eid, component: component)
    }

    @inline(__always)
    public mutating func add(eid: EntityId, component: T) {
        handle.pfstorage.add(eid: eid, component: component)
    }

    @inline(__always)
    public mutating func remove(eid: EntityId) {
        handle.pfstorage.remove(eid: eid)
    }

    @inline(__always)
    public func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        handle.pfstorage.getWithDenseIndex_Uncheck(index)
    }

    @inline(__always)
    public func get(_ eid: EntityId) -> Any? {
        handle.pfstorage.get(eid)
    }

    @inline(__always) public var storageType: any Component.Type { T.self }
    @inline(__always) public var activeEntityCount: Int { handle.pfstorage.activeEntityCount }
    @inline(__always) var segmentCount : Int { handle.pfstorage.segmentCount }
    @inline(__always) var firstActiveSegment: Int { handle.pfstorage.firstActiveSegment }
    @inline(__always) var lastActiveSegment: Int { handle.pfstorage.lastActiveSegment }
    @inline(__always) var activeSegmentCount: Int { handle.pfstorage.activeSegmentCount }
    
    // @inlinable
    // func segmentBlockMaskWith(mask: inout UInt64, _ i: Int) {
    //     if mask == 0 { return }
    //     if i > handle.pfstorage.lastActiveSegment { mask = UInt64(0); return; } // for more segment
    //     if let segment = handle.pfstorage.segments[i] {
    //         segment.block_MaskOut_With(blockMask: &mask)
    //     } else {
    //         mask = UInt64(0)
    //     }
    // }

    // @inlinable
    // func segmentPageMaskWith_Uncheck(mask: inout UInt64, blockIdx: Int, pageIdx: Int) {
    //     if mask == 0 { return }
    //     let segment = handle.pfstorage.segments[blockIdx]!
    //     segment.page_I_MaskOut_With(pageMask: &mask, pageIdx)
    // }

    @inline(__always)
    func get_SparseSetL2_CompMutPointer_Uncheck(_ blockIdx: Int) -> UnsafeMutablePointer<T> {
        handle.pfstorage.getSegmentComponentsRawPointer_Internal(blockIdx)
    }
    
    @inline(__always)
    func get_SparseSetL2_PagePointer_Uncheck(_ blockIdx: Int) -> PagePtr<T> {
        PagePtr(ptr: handle.pfstorage.segments[blockIdx].pointee.getPageMasksPointer())
    }

    @inline(__always)
    var segments: UnsafePointer<UnsafeMutablePointer<SparseSet_L2_2<T>>> {
        handle.pfstorage.getSegmentsRawPointer_Internal()
    }

    @inline(__always)
    func isActiveSegment(_ blockIdx: Int) -> Bool {
        if blockIdx < 0 || blockIdx >= handle.pfstorage.segments.count { return false }
        return handle.pfstorage.segments[blockIdx] != handle.pfstorage.sentinelPtr
    }

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
            yield handle.pfstorage
        }
    }
}

extension PFStorageBox: Component where T: Component {
    public static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox<Self>(PFStorageHandle<Self>())
    }
}
