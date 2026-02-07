import Foundation

let SparseSet_L2_BaseMask: UInt64 = 0xFFFFFFFFFFFFFFFF

// extension SparseSet_L2 {
//     @inlinable
//     func block_MaskOut_With(blockMask: inout UInt64) {
//         blockMask &= sparse.blockMask
//     }

//     @inlinable
//     func block_MaskOut_NotWith(blockMask: inout UInt64) {
//         blockMask &= ~sparse.blockMask
//     }

//     @inlinable // should: 0 <= i <= 63
//     func page_I_MaskOut_With(pageMask: inout UInt64, _ i: Int) {
//         pageMask &= sparse.pageOnBlock[i].pageMask
//     }

//     @inlinable // should: 0 <= i <= 63
//     func page_I_MaskOut_NotWith(pageMask: inout UInt64, _ i: Int) {
//         pageMask &= ~sparse.pageOnBlock[i].pageMask
//     }
// }

// func getMinimum_ActiveMemberNumber_OfStorages<each T>(
//     _ storages: borrowing (repeat PFStorageBox<each T>)
// ) -> Int 
// {
//     var minimum = Int.max
//     for storage in repeat each storages {
//         minimum = min(minimum, storage.activeEntityCount)
//     }
//     return minimum
// }

// func getMinimum_LastActiveSection_OfStorages<each T>(
//     _ storages: borrowing (repeat PFStorageBox<each T>)
// ) -> Int 
// {
//     var minimum = Int.max
//     for storage in repeat each storages {
//         minimum = min(minimum, storage.lastActiveSegment)
//     }
//     return minimum
// }

// func getMaximum_FirstActiveSection_OfStorages<each T>(
//     _ storages: borrowing (repeat PFStorageBox<each T>)
// ) -> Int 
// {
//     var maximum = Int.min
//     for storage in repeat each storages {
//         maximum = max(maximum, storage.firstActiveSegment)
//     }
//     return maximum
// }

@inlinable
func getStorages<each T>(
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ tokens: borrowing (repeat TypeToken<each T>)
) -> (repeat PFStorageBox<each T>)
{
    (repeat (each tokens).getStorage(base: base))
}


@usableFromInline
struct ViewPlan: Sendable {
    let segmentIndex: Int
    let mask: UInt64
}

@inline(__always)
func createViewPlans<each T, each WT, each WOT>( 
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: (repeat TypeToken<each T>),
    withTag: (repeat TypeToken<each WT>),
    withoutTag: (repeat TypeToken<each WOT>),
) -> (ContiguousArray<ViewPlan>, (repeat PFStorageBox<each T>), (repeat PFStorageBox<each WT>), (repeat PFStorageBox<each WOT>))
{
    let storages: (repeat PFStorageBox<each T>) = (repeat (each with).getStorage(base: base))
    let wt_storages: (repeat PFStorageBox<each WT>) = (repeat (each withTag).getStorage(base: base))
    let wot_storages: (repeat PFStorageBox<each WOT>) = (repeat (each withoutTag).getStorage(base: base))

    var global_First = Int.min; repeat maxHelper(&global_First, (each storages).firstActiveSegment);
    repeat maxHelper(&global_First, (each wt_storages).firstActiveSegment)
    var global_Last = Int.max; repeat minHelper(&global_Last, (each storages).lastActiveSegment);
    repeat minHelper(&global_Last, (each wt_storages).lastActiveSegment)
    guard global_First != Int.min, global_Last != Int.max else { 
        fatalError("ECS Query Error: At least one inclusive component or tag is required to define the search range.") 
    }

    if global_First > global_Last { return ([], storages, wt_storages, wot_storages) }

    var global_Minimum_ActiveSegmentCount = Int.max; repeat minHelper(&global_Minimum_ActiveSegmentCount, (each storages).activeSegmentCount);
    repeat minHelper(&global_Minimum_ActiveSegmentCount, (each wt_storages).activeSegmentCount)

    var viewPlans = ContiguousArray<ViewPlan>()
    let estimated_space = min(global_Minimum_ActiveSegmentCount, global_Last - global_First + 1)
    viewPlans.reserveCapacity(estimated_space)
    let allSegments = (repeat (each storages).segments)
    let wt_allSegments = (repeat (each wt_storages).segments)
    let wot_allSegments = (repeat (each wot_storages).segments)
    
    for i in stride(from: global_First, through: global_Last, by: 1) {
        var segment_i_mask = SparseSet_L2_BaseMask
        repeat segment_i_mask &= (each allSegments).advanced(by: i).pointee?.sparse.blockMask ?? 0
        repeat segment_i_mask &= (each wt_allSegments).advanced(by: i).pointee?.sparse.blockMask ?? 0
        repeat segment_i_mask &= ~((each wot_allSegments).advanced(by: i).pointee?.sparse.blockMask ?? 0)
        
        if segment_i_mask != 0 {
            viewPlans.append(ViewPlan(segmentIndex: i, mask: segment_i_mask)) 
        }
    }
    
    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)

    return (viewPlans, storages, wt_storages, wot_storages)
}

@inline(__always)
func executeViewPlans<each T, each WT, each WOT> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    viewPlans: ContiguousArray<ViewPlan>,
    storages: (repeat PFStorageBox<each T>),
    wt_storages: (repeat PFStorageBox<each WT>), 
    wot_storages: (repeat PFStorageBox<each WOT>),
    _ action: (_ taskId: Int, _ pack: repeat ComponentProxy<each T>) -> Void
) {
    let wot_allSegments = (repeat (each wot_storages).segments)
    for vp in viewPlans {
        var blockMask = vp.mask
        let segmentIndex = vp.segmentIndex
        let dataPtrs = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex))
        let pagePtrs = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex))
        let wt_pagePtrs = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex))
        let wot_allSegment = (repeat (each wot_allSegments).advanced(by: segmentIndex).pointee)

        // ###################################################### Sparse_Set_L2_i
        while blockMask != 0 { 
            let pageIdx = blockMask.trailingZeroBitCount
            let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
            var pageMask = SparseSet_L2_BaseMask
            repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
            repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
            repeat pageMask &= ~((each wot_allSegment)?.sparse.pageOnBlock[pageIdx].pageMask ?? 0 )

            while pageMask != 0 {
                let slotIdx = pageMask.trailingZeroBitCount
                // do action here
                // ############################################################################
                action(0, 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                    )
                )
                // ############################################################################
                // end
                pageMask &= (pageMask - 1)
            }
            // end
            blockMask &= (blockMask - 1)
        }
        // ###################################################### Sparse_Set_L2_i
    }
    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)
}

@inline(__always)
public func view<each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    _ action: (_: Int, _: repeat ComponentProxy<each T>) -> Void
) {
    let (vps, storages, _, _) = createViewPlans( base: base, with: (repeat each with), withTag: (), withoutTag: () )
    executeViewPlans(base: base, viewPlans: vps, storages: (repeat each storages), wt_storages: (), wot_storages: (), action)
}

// single componet
@inline(__always)
public func view<T>(
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>, 
    with: TypeToken<T>,
    _ action: (_: Int, _: ComponentProxy<T>) -> Void
) {
    let (vps, storage, _, _) = createViewPlans( base: base, with: with, withTag: (), withoutTag: () )
    
    for vp in vps {
        let blockId = vp.segmentIndex
        let count = storage.segments[blockId]?.count ?? 0
        let dataPtr = storage.get_SparseSetL2_CompMutPointer_Uncheck(blockId)

        for i in 0..<count {
            // taskId = 0
            action(0, ComponentProxy<T>(pointer: dataPtr.advanced(by: i) ))
        }
    }

    _fixLifetime(storage)
}

@inline(__always)
func minHelper(_ minimum: inout Int, _ new: borrowing Int) {
    minimum = min(minimum, new)
}

@inline(__always)
func maxHelper(_ maximum: inout Int, _ new: borrowing Int) {
    maximum = max(maximum, new)
}

// static view
public protocol SystemBody {
    associatedtype Components
    
    @inline(__always)
    @inlinable 
    func execute(taskId: Int, components: Components)
}

@inline(__always)
func executeViewPlans<S: SystemBody, each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    viewPlans: ContiguousArray<ViewPlan>,
    storages: (repeat PFStorageBox<each T>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) // 強制型別對齊
{

    for vp in viewPlans {
        var blockMask = vp.mask
        // 預先取出這一塊 Segment 的指針
        let dataPtrs = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(vp.segmentIndex))
        let pagePtrs = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(vp.segmentIndex))
        
        // ###################################################### Sparse_Set_L2_i
        while blockMask != 0 { 
            let pageIdx = blockMask.trailingZeroBitCount
            let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
            var pageMask = SparseSet_L2_BaseMask
            repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask

            while pageMask != 0 {
                let slotIdx = pageMask.trailingZeroBitCount
                
                // ############################################################################
                // 這裡發生了改變：我們構建一個 Tuple 傳給 body.execute
                // 因為 S 是具體的 Struct，編譯器會在這裡直接展開代碼 (Inline)
                body.execute(
                    taskId: 0, 
                    components: ( 
                        repeat ComponentProxy(
                            pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                        )
                    )
                    
                )
                // ############################################################################
                
                pageMask &= (pageMask - 1)
            }
            blockMask &= (blockMask - 1)
        }
        // ###################################################### Sparse_Set_L2_i
    }
    repeat _fixLifetime(each storages)
}

// 重構後的入口 View
@inline(__always)
public func view<S: SystemBody, each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) 
{
    let (vps, storages, _, _) = createViewPlans(base: base, with: (repeat each with), withTag: (), withoutTag: ())
    executeViewPlans(base: base, viewPlans: vps, storages: (repeat each storages), body)
}

// static single componet
@inline(__always)
public func view<S: SystemBody, T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>, 
    with: TypeToken<T>,
    _ body: borrowing S
) where S.Components == ComponentProxy<T>
{
    let (vps, storage, _, _) = createViewPlans( base: base, with: with, withTag: (), withoutTag: () )

    for vp in vps {
        let blockId = vp.segmentIndex
        let count = storage.segments[blockId]?.count ?? 0
        let dataPtr = storage.get_SparseSetL2_CompMutPointer_Uncheck(blockId)

        for i in 0..<count {
            body.execute(
                taskId: 0, 
                components: ComponentProxy(pointer: dataPtr.advanced(by: i))
            )
        }
    }

    _fixLifetime(storage)
}





// @inline(__always)
// func executeViewPlansParallel<each T: Sendable>(
//     base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
//     viewPlans: ContiguousArray<ViewPlan>,
//     with: borrowing (repeat TypeToken<each T>),
//     coresNum: Int,
//     _ action: @escaping @Sendable (_ taskId: Int, _ pack: repeat ComponentProxy<each T>) -> Void
// ) async {
//     let processorCount = min(ProcessInfo.processInfo.activeProcessorCount, coresNum)
//     let planCount = viewPlans.count
//     if planCount < processorCount || planCount < 8 {
//         executeViewPlans(base: base, viewPlans: viewPlans, with: (repeat each with), action)
//         return
//     }

//     let storages = (repeat (each with).getStorage(base: base))
//     await withTaskGroup(of: Void.self) { group in
//         let chunkSize = (planCount + processorCount - 1) / processorCount
//         for i in stride(from: 0, to: planCount, by: chunkSize) {
//             let range = i..<min(i + chunkSize, planCount)
//             let chunk = Array(viewPlans[range])
//             let taskId = i / chunkSize
//             // ##################################################################################### core task
//             group.addTask {
//                 // 每個 Task 處理一組獨立的 Segments
//                 for vp in chunk {
//                     var blockMask = vp.mask
//                     let dataPtrs = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(vp.segmentIndex))
//                     let pagePtrs = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(vp.segmentIndex))

//                     // ##################################################################################### Sparse_Set_L2_i
//                     while blockMask != 0 {
//                         let pageIdx = blockMask.trailingZeroBitCount
//                         let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
//                         var pageMask = SparseSet_L2_BaseMask
//                         repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask

//                         while pageMask != 0 {
//                             let slotIdx = pageMask.trailingZeroBitCount
//                             action( 
//                                 taskId,
//                                 repeat ComponentProxy(pointer: (each dataPtrs).advanced(by: (each entityOnPagePtrs).getSlotCompArrIdx_Uncheck(slotIdx)))
//                             )
//                             pageMask &= (pageMask - 1)
//                         }
//                         blockMask &= (blockMask - 1)
//                     }
//                     // ##################################################################################### Sparse_Set_L2_i

//                 }
//             }
//             // ##################################################################################### core task
//         }
//     }
//     repeat _fixLifetime(each storages)
// }

// @inline(__always)
// public func viewParallel<each T: Sendable> (
//     base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
//     with: borrowing (repeat TypeToken<each T>),
//     coresNum: Int = 4,
//     _ action: @escaping @Sendable (_ taskId: Int, _ pack: repeat ComponentProxy<each T>) -> Void
// ) async {
//     let vps = createViewPlans( base: base, with: (repeat each with) )
//     await executeViewPlansParallel(base: base, viewPlans: vps, with: (repeat each with), coresNum: coresNum, action)
// }
