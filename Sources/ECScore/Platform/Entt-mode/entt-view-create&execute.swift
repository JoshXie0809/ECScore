let SparseSet_L2_BaseMask: UInt64 = 0xFFFFFFFFFFFFFFFF

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
    @inline(__always) let segmentIndex: Int
    @inline(__always) let mask: UInt64
}

@usableFromInline
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

    var global_First = Int.min
    var global_Last = Int.max
    var minActiveSegments = Int.max
    repeat absorbInclusiveMeta(&global_First, &global_Last, &minActiveSegments, each storages)
    repeat absorbInclusiveMeta(&global_First, &global_Last, &minActiveSegments, each wt_storages)

    guard global_First != Int.min, global_Last != Int.max else { 
        fatalError("ECS createViewPlans Error: At least one inclusive component or tag is required to define the search range.") 
    }

    if global_First > global_Last { return ([], storages, wt_storages, wot_storages) }

    var viewPlans = ContiguousArray<ViewPlan>()
    let scanSegmentCount = global_Last - global_First + 1
    viewPlans.reserveCapacity(min(minActiveSegments, scanSegmentCount))
    
    let allSegments = (repeat (each storages).segments)
    let wt_allSegments = (repeat (each wt_storages).segments)
    
    for i in stride(from: global_First, through: global_Last, by: 1) {
        var segment_i_mask = SparseSet_L2_BaseMask
        repeat segment_i_mask &= (each allSegments).advanced(by: i).pointee.pointee.sparse.blockMask
        repeat segment_i_mask &= (each wt_allSegments).advanced(by: i).pointee.pointee.sparse.blockMask
        
        if segment_i_mask != 0 {
            viewPlans.append(ViewPlan(segmentIndex: i, mask: segment_i_mask)) 
        }
    }
    
    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)

    return (viewPlans, storages, wt_storages, wot_storages)
}

@usableFromInline
@inline(__always)
func executeViewPlans<each T, each WT, each WOT> (
    viewPlans: ContiguousArray<ViewPlan>,
    storages: borrowing (repeat PFStorageBox<each T>),
    wt_storages: borrowing (repeat PFStorageBox<each WT>), 
    wot_storages: borrowing (repeat PFStorageBox<each WOT>),
    _ action: (_ taskId: Int, _: repeat ComponentProxy<each T>) -> Void
) {
    let count = viewPlans.count
    guard count != 0 else { return }
    
    let wot_allSegments = (repeat (each wot_storages).segments)
    var blockMask_now = viewPlans[0].mask
    var segmentIndex_now = viewPlans[0].segmentIndex
    var dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
    let _ = (repeat (each dataPtrs_now).pointee)

    var pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)

    let _ = (repeat (each pagePtrs_now).ptr.pointee)
    let _ = (repeat (each wt_pagePtrs_now).ptr.pointee)
    let _ = (repeat (each wot_allSegment_now).pointee.sparse)

    for i in stride(from: 1, to: count, by: 1) {
        var blockMask = blockMask_now
        let dataPtrs = dataPtrs_now
        let pagePtrs = pagePtrs_now
        let wt_pagePtrs = wt_pagePtrs_now
        let wot_allSegment = wot_allSegment_now

        // update next
        blockMask_now = viewPlans[i].mask
        segmentIndex_now = viewPlans[i].segmentIndex
        dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
        let _ = (repeat (each dataPtrs_now).pointee)
        
        pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)

        let _ = (repeat (each pagePtrs_now).ptr.pointee)
        let _ = (repeat (each wt_pagePtrs_now).ptr.pointee)
        let _ = (repeat (each wot_allSegment_now).pointee.sparse)

        // ###################################################### Sparse_Set_L2_i
        var now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1)

        while blockMask != 0 {
            let pageIdx = now_pageIdx
            now_pageIdx = blockMask.trailingZeroBitCount
            blockMask &= (blockMask - 1)

            let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
            var pageMask = SparseSet_L2_BaseMask
            repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
            repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
            repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)
            
            while pageMask != 0 {
                let slotIdx = pageMask.trailingZeroBitCount
                pageMask &= (pageMask - 1)
                // do action here
                // ############################################################################
                action(0, 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                    )
                )
                // ############################################################################
            }
        }

        let pageIdx = now_pageIdx
        let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
        var pageMask = SparseSet_L2_BaseMask
        repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)
        
        while pageMask != 0 {
            let slotIdx = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            // ############################################################################
            action(0, 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                )
            )
            // ############################################################################
        }

        // ###################################################### Sparse_Set_L2_i
    }

    var blockMask = blockMask_now
    let dataPtrs = dataPtrs_now
    let pagePtrs = pagePtrs_now
    let wt_pagePtrs = wt_pagePtrs_now
    let wot_allSegment = wot_allSegment_now

    var now_pageIdx = blockMask.trailingZeroBitCount
    blockMask &= (blockMask - 1) 

    while blockMask != 0 {
        let pageIdx = now_pageIdx
        now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1)

        let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
        var pageMask = SparseSet_L2_BaseMask
        repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)
        
        while pageMask != 0 {
            let slotIdx = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            action(0, 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                )
            )
        }
    }

    let pageIdx = now_pageIdx
    let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
    var pageMask = SparseSet_L2_BaseMask
    repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
    repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
    repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)
    
    while pageMask != 0 {
        let slotIdx = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        action(0, 
            repeat ComponentProxy(
                pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
            )
        )
    }

    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)
}


@usableFromInline
@inline(__always)
func minHelper(_ minimum: inout Int, _ new: borrowing Int) {
    minimum = min(minimum, new)
}

@usableFromInline
@inline(__always)
func maxHelper(_ maximum: inout Int, _ new: borrowing Int) {
    maximum = max(maximum, new)
}

@usableFromInline
@inline(__always)
func absorbInclusiveMeta<T>(
    _ global_First: inout Int,
    _ global_Last: inout Int,
    _ minActiveSegments: inout Int,
    _ storage: borrowing PFStorageBox<T>
) {
    maxHelper(&global_First, storage.firstActiveSegment)
    minHelper(&global_Last, storage.lastActiveSegment)
    minHelper(&minActiveSegments, storage.activeSegmentCount)
}

// static view
public protocol SystemBody {
    associatedtype Components
    
    @inline(__always)
    @inlinable 
    func execute(taskId: Int, components: borrowing Components)
}


@usableFromInline
@inline(__always)
func executeViewPlans<S: SystemBody, each T, each WT, each WOT> (
    viewPlans: ContiguousArray<ViewPlan>,
    storages: borrowing (repeat PFStorageBox<each T>),
    wt_storages: borrowing (repeat PFStorageBox<each WT>), 
    wot_storages: borrowing (repeat PFStorageBox<each WOT>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>) // 強制型別對齊
{
    let count = viewPlans.count
    guard count != 0 else { return }
    
    let wot_allSegments = (repeat (each wot_storages).segments)

    var blockMask_now = viewPlans[0].mask
    var segmentIndex_now = viewPlans[0].segmentIndex
    var dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
    let _ = (repeat (each dataPtrs_now).pointee)

    var pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)

    let _ = (repeat (each pagePtrs_now).ptr.pointee)
    let _ = (repeat (each wt_pagePtrs_now).ptr.pointee)
    let _ = (repeat (each wot_allSegment_now).pointee.sparse)

    for i in stride(from: 1, to: count, by: 1) {
        var blockMask = blockMask_now
        let dataPtrs = dataPtrs_now
        let pagePtrs = pagePtrs_now
        let wt_pagePtrs = wt_pagePtrs_now
        let wot_allSegment = wot_allSegment_now

        // update next
        blockMask_now = viewPlans[i].mask
        segmentIndex_now = viewPlans[i].segmentIndex
        dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
        let _ = (repeat (each dataPtrs_now).pointee)

        pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)

        let _ = (repeat (each pagePtrs_now).ptr.pointee)
        let _ = (repeat (each wt_pagePtrs_now).ptr.pointee)
        let _ = (repeat (each wot_allSegment_now).pointee.sparse)
        
        // ###################################################### Sparse_Set_L2_i
        var now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1) 

        while blockMask != 0 { 
            let pageIdx = now_pageIdx
            now_pageIdx = blockMask.trailingZeroBitCount

            blockMask &= (blockMask - 1)
            let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
            var pageMask = SparseSet_L2_BaseMask
            repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
            repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
            repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)

            while pageMask != 0 {
                let slotIdx = pageMask.trailingZeroBitCount
                pageMask &= (pageMask - 1)
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

            }
        }

        let pageIdx = now_pageIdx
        let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
        var pageMask = SparseSet_L2_BaseMask
        repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)

        while pageMask != 0 {
            let slotIdx = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            // ############################################################################
            body.execute(
                taskId: 0, 
                components: ( 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                    )
                )
            )
            // ############################################################################
        }

        // ###################################################### Sparse_Set_L2_i
    }

    var blockMask = blockMask_now
    let dataPtrs = dataPtrs_now
    let pagePtrs = pagePtrs_now
    let wt_pagePtrs = wt_pagePtrs_now
    let wot_allSegment = wot_allSegment_now

    // ###################################################### Sparse_Set_L2_i
    var now_pageIdx = blockMask.trailingZeroBitCount
    blockMask &= (blockMask - 1) 

    while blockMask != 0 { 
        let pageIdx = now_pageIdx
        now_pageIdx = blockMask.trailingZeroBitCount

        blockMask &= (blockMask - 1)
        let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
        var pageMask = SparseSet_L2_BaseMask
        repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
        repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)

        while pageMask != 0 {
            let slotIdx = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
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

        }
    }

    let pageIdx = now_pageIdx
    let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
    var pageMask = SparseSet_L2_BaseMask
    repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
    repeat pageMask &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask
    repeat pageMask &= ~((each wot_allSegment).pointee.sparse.pageOnBlock[pageIdx].pageMask)

    while pageMask != 0 {
        let slotIdx = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        // ############################################################################
        body.execute(
            taskId: 0, 
            components: ( 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(by: Int((each entityOnPagePtrs).ptr.advanced(by: slotIdx).pointee.compArrIdx))
                )
            )
        )
        // ############################################################################
    }

    // ###################################################### Sparse_Set_L2_i

    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)
}













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
