public let SparseSet_L2_BaseMask: UInt64 = 0xFFFFFFFFFFFFFFFF

@inlinable
func getStorages<each T>(
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ tokens: borrowing (repeat TypeToken<each T>)
) -> (repeat PFStorageBox<each T>)
{
    (repeat (each tokens).getStorage(base: base))
}

public struct ViewPlan: Sendable {
    public let segmentIndex: Int
    public let mask: UInt64
    
    @inlinable
    public init(segmentIndex: Int, mask: UInt64) {
        self.segmentIndex = segmentIndex
        self.mask = mask
    }
}

@inlinable
@inline(__always)
func createViewPlans<each T, each WT, each WOT>( 
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: (repeat TypeToken<each T>),
    withTag: (repeat TypeToken<each WT>),
    withoutTag: (repeat TypeToken<each WOT>),
) -> (ContiguousArray<ViewPlan>, (repeat PFStorageBox<each T>), (repeat PFStorageBox<each WT>), (repeat PFStorageBox<each WOT>))
where repeat (each T).SparseSetType: DenseSparseSet
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
    
    var i = global_First
    if scanSegmentCount >= 4 {
        let unrolledLast = global_Last - 3
        var base_i = i

        var withMask4_now = SIMD4<UInt64>(repeating: SparseSet_L2_BaseMask)
        var wtMask4_now = SIMD4<UInt64>(repeating: SparseSet_L2_BaseMask)

        repeat withMask4_now &= SIMD4<UInt64>(
            (each allSegments).advanced(by: base_i).pointee.pointee.blockMask,
            (each allSegments).advanced(by: base_i + 1).pointee.pointee.blockMask,
            (each allSegments).advanced(by: base_i + 2).pointee.pointee.blockMask,
            (each allSegments).advanced(by: base_i + 3).pointee.pointee.blockMask
        )

        repeat wtMask4_now &= SIMD4<UInt64>(
            (each wt_allSegments).advanced(by: base_i).pointee.pointee.blockMask,
            (each wt_allSegments).advanced(by: base_i + 1).pointee.pointee.blockMask,
            (each wt_allSegments).advanced(by: base_i + 2).pointee.pointee.blockMask,
            (each wt_allSegments).advanced(by: base_i + 3).pointee.pointee.blockMask
        )

        while true {
            let mask4 = withMask4_now & wtMask4_now
            if mask4[0] != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i, mask: mask4[0])) }
            if mask4[1] != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i + 1, mask: mask4[1])) }
            if mask4[2] != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i + 2, mask: mask4[2])) }
            if mask4[3] != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i + 3, mask: mask4[3])) }

            let nextBase = base_i + 4
            if nextBase > unrolledLast {
                i = nextBase
                break
            }

            _preheat(
                (repeat (each allSegments).advanced(by: nextBase).pointee.pointee.blockMask),
                (repeat (each wt_allSegments).advanced(by: nextBase).pointee.pointee.blockMask)
            )

            withMask4_now = SIMD4<UInt64>(repeating: SparseSet_L2_BaseMask)
            wtMask4_now = SIMD4<UInt64>(repeating: SparseSet_L2_BaseMask)

            repeat withMask4_now &= SIMD4<UInt64>(
                (each allSegments).advanced(by: nextBase).pointee.pointee.blockMask,
                (each allSegments).advanced(by: nextBase + 1).pointee.pointee.blockMask,
                (each allSegments).advanced(by: nextBase + 2).pointee.pointee.blockMask,
                (each allSegments).advanced(by: nextBase + 3).pointee.pointee.blockMask
            )

            repeat wtMask4_now &= SIMD4<UInt64>(
                (each wt_allSegments).advanced(by: nextBase).pointee.pointee.blockMask,
                (each wt_allSegments).advanced(by: nextBase + 1).pointee.pointee.blockMask,
                (each wt_allSegments).advanced(by: nextBase + 2).pointee.pointee.blockMask,
                (each wt_allSegments).advanced(by: nextBase + 3).pointee.pointee.blockMask
            )

            base_i = nextBase
        }
    }

    while i <= global_Last {
        var m = SparseSet_L2_BaseMask
        repeat (m &= (each allSegments).advanced(by: i).pointee.pointee.blockMask)
        repeat (m &= (each wt_allSegments).advanced(by: i).pointee.pointee.blockMask)
        if m != 0 {
            viewPlans.append(ViewPlan(segmentIndex: i, mask: m))
        }
        i += 1
    }
    
    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)

    return (viewPlans, storages, wt_storages, wot_storages)
}

@usableFromInline
@inline(__always)
func executeViewPlans<each T, each WT, each WOT> (
    entities: any Platform_Entity,
    viewPlans: ContiguousArray<ViewPlan>,
    storages: borrowing (repeat PFStorageBox<each T>),
    wt_storages: borrowing (repeat PFStorageBox<each WT>), 
    wot_storages: borrowing (repeat PFStorageBox<each WOT>),
    _ action: (_ taskId: Int, _: repeat ComponentProxy<each T>) -> Void
) where repeat (each T).SparseSetType: DenseSparseSet {
    let count = viewPlans.count
    guard count != 0 else { return }
    let entities_activeMaskPtr = entities._activeMaskPtr
    
    let wot_allSegments = (repeat (each wot_storages).segments)
    var blockMask_now = viewPlans[0].mask
    var segmentIndex_now = viewPlans[0].segmentIndex
    var dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
    _preheat((repeat (each dataPtrs_now).pointee))

    var pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)
    var sparsePtrs_now = (repeat (each storages).segments.advanced(by: segmentIndex_now).pointee.pointee.getSparseEntriesPointer())
    
    _preheat((repeat (each pagePtrs_now).ptr.pointee))
    _preheat((repeat (each wt_pagePtrs_now).ptr.pointee))
    _preheat((repeat (each wot_allSegment_now).pointee))

    for i in stride(from: 1, to: count, by: 1) {
        var blockMask = blockMask_now
        let dataPtrs = dataPtrs_now
        let pagePtrs = pagePtrs_now
        let wt_pagePtrs = wt_pagePtrs_now
        let wot_allSegment = wot_allSegment_now
        let blockIdx = segmentIndex_now
        let sparsePtrs = sparsePtrs_now

        // update next
        blockMask_now = viewPlans[i].mask
        segmentIndex_now = viewPlans[i].segmentIndex
        dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
        _preheat((repeat (each dataPtrs_now).pointee))
        
        pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)
        sparsePtrs_now = (repeat (each storages).segments.advanced(by: segmentIndex_now).pointee.pointee.getSparseEntriesPointer())

        _preheat((repeat (each pagePtrs_now).ptr.pointee))
        _preheat((repeat (each wt_pagePtrs_now).ptr.pointee))
        _preheat((repeat (each wot_allSegment_now).pointee))

        // ###################################################### Sparse_Set_L2_i
        var now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1)

        while blockMask != 0 {
            let pageIdx = now_pageIdx
            now_pageIdx = blockMask.trailingZeroBitCount
            blockMask &= (blockMask - 1)
            
            var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
            var pageMask2 = SparseSet_L2_BaseMask
            var pageMask3 = UInt64(0)
            repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
            repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
            repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
            var pageMask = pageMask1 & pageMask2 & (~pageMask3)

            // ###################################################################################################
            if pageMask == 0 { continue }
            var slotIdx_now = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            var entityOffset_now = (pageIdx << 6) + slotIdx_now

            while pageMask != 0 {
                let entityOffset = entityOffset_now

                slotIdx_now = pageMask.trailingZeroBitCount
                pageMask &= (pageMask - 1)
                entityOffset_now = (pageIdx << 6) + slotIdx_now

                action(0, 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(
                            by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                        )
                    )
                )
            }

            let entityOffset = entityOffset_now
            action(0, 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(
                        by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                    )
                )
            )
            // ###################################################################################################

        }

        let pageIdx = now_pageIdx

        var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
        var pageMask2 = SparseSet_L2_BaseMask
        var pageMask3 = UInt64(0)
        repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
        var pageMask = pageMask1 & pageMask2 & (~pageMask3)
        
        // ###################################################################################################
        if pageMask == 0 { continue }
        var slotIdx_now = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        var entityOffset_now = (pageIdx << 6) + slotIdx_now

        while pageMask != 0 {
            let entityOffset = entityOffset_now

            slotIdx_now = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            entityOffset_now = (pageIdx << 6) + slotIdx_now

            action(0, 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(
                        by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                    )
                )
            )
        }

        let entityOffset = entityOffset_now
        action(0, 
            repeat ComponentProxy(
                pointer: (each dataPtrs).advanced(
                    by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                )
            )
        )
        // ###################################################################################################
        
    }

    var blockMask = blockMask_now
    let dataPtrs = dataPtrs_now
    let pagePtrs = pagePtrs_now
    let wt_pagePtrs = wt_pagePtrs_now
    let wot_allSegment = wot_allSegment_now
    let blockIdx = segmentIndex_now
    let sparsePtrs = sparsePtrs_now

    var now_pageIdx = blockMask.trailingZeroBitCount
    blockMask &= (blockMask - 1) 

    while blockMask != 0 {
        let pageIdx = now_pageIdx
        now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1)

        var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
        var pageMask2 = SparseSet_L2_BaseMask
        var pageMask3 = UInt64(0)
        repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
        var pageMask = pageMask1 & pageMask2 & (~pageMask3)

        // ###################################################################################################
        if pageMask == 0 { continue }
        var slotIdx_now = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        var entityOffset_now = (pageIdx << 6) + slotIdx_now

        while pageMask != 0 {
            let entityOffset = entityOffset_now

            slotIdx_now = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            entityOffset_now = (pageIdx << 6) + slotIdx_now

            action(0, 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(
                        by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                    )
                )
            )
        }

        let entityOffset = entityOffset_now
        action(0, 
            repeat ComponentProxy(
                pointer: (each dataPtrs).advanced(
                    by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                )
            )
        )
        // ###################################################################################################
    }

    let pageIdx = now_pageIdx

    var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
    var pageMask2 = SparseSet_L2_BaseMask
    var pageMask3 = UInt64(0)
    repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
    repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
    repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
    var pageMask = pageMask1 & pageMask2 & (~pageMask3)
    
    while pageMask != 0 {
        let slotIdx = pageMask.trailingZeroBitCount
        let entityOffset = (pageIdx << 6) + slotIdx

        pageMask &= (pageMask - 1)
        action(0, 
            repeat ComponentProxy(
                pointer: (each dataPtrs).advanced(
                    by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                )
            )
        )
    }

    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)
    _fixLifetime(entities)
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
@inline(never)
func _preheat<each T>(_ value:repeat borrowing each T) {}

@usableFromInline
@inline(__always)
func executeViewPlans<S: SystemBody, each T, each WT, each WOT> (
    entities: any Platform_Entity,
    viewPlans: ContiguousArray<ViewPlan>,
    storages: borrowing (repeat PFStorageBox<each T>),
    wt_storages: borrowing (repeat PFStorageBox<each WT>), 
    wot_storages: borrowing (repeat PFStorageBox<each WOT>),
    _ body: borrowing S
) where S.Components == (repeat ComponentProxy<each T>), repeat (each T).SparseSetType: DenseSparseSet // 強制型別對齊
{
    let count = viewPlans.count
    guard count != 0 else { return }
    
    let entities_activeMaskPtr = entities._activeMaskPtr
    let wot_allSegments = (repeat (each wot_storages).segments)

    var blockMask_now = viewPlans[0].mask
    var segmentIndex_now = viewPlans[0].segmentIndex
    var dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
    _preheat((repeat (each dataPtrs_now).pointee))

    var pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
    var wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)
    var sparsePtrs_now = (repeat (each storages).segments.advanced(by: segmentIndex_now).pointee.pointee.getSparseEntriesPointer())

    _preheat((repeat (each pagePtrs_now).ptr.pointee))
    _preheat((repeat (each wt_pagePtrs_now).ptr.pointee))
    _preheat((repeat (each wot_allSegment_now).pointee))

    for i in stride(from: 1, to: count, by: 1) {
        var blockMask = blockMask_now
        let dataPtrs = dataPtrs_now
        let pagePtrs = pagePtrs_now
        let wt_pagePtrs = wt_pagePtrs_now
        let wot_allSegment = wot_allSegment_now
        let blockIdx = segmentIndex_now
        let sparsePtrs = sparsePtrs_now

        // update next
        blockMask_now = viewPlans[i].mask
        segmentIndex_now = viewPlans[i].segmentIndex
        dataPtrs_now = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(segmentIndex_now))
        _preheat((repeat (each dataPtrs_now).pointee))

        pagePtrs_now = (repeat (each storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wt_pagePtrs_now = (repeat (each wt_storages).get_SparseSetL2_PagePointer_Uncheck(segmentIndex_now))
        wot_allSegment_now = (repeat (each wot_allSegments).advanced(by: segmentIndex_now).pointee)
        sparsePtrs_now = (repeat (each storages).segments.advanced(by: segmentIndex_now).pointee.pointee.getSparseEntriesPointer())

        _preheat((repeat (each pagePtrs_now).ptr.pointee))
        _preheat((repeat (each wt_pagePtrs_now).ptr.pointee))
        _preheat((repeat (each wot_allSegment_now).pointee))

        // ###################################################### Sparse_Set_L2_i
        var now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1) 

        while blockMask != 0 { 
            let pageIdx = now_pageIdx
            now_pageIdx = blockMask.trailingZeroBitCount
            blockMask &= (blockMask - 1)

            var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
            var pageMask2 = SparseSet_L2_BaseMask
            var pageMask3 = UInt64(0)
            repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
            repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
            repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
            var pageMask = pageMask1 & pageMask2 & (~pageMask3)
            
            // ############################################################################
            if pageMask == 0 { continue }
            var slotIdx_now = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            var entityOffset_now = (pageIdx << 6) + slotIdx_now
            
            while pageMask != 0 {
                let entityOffset = entityOffset_now

                slotIdx_now = pageMask.trailingZeroBitCount
                pageMask &= (pageMask - 1)
                entityOffset_now = (pageIdx << 6) + slotIdx_now

                body.execute(
                    taskId: 0, 
                    components: ( 
                        repeat ComponentProxy(
                            pointer: (each dataPtrs).advanced(
                                by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                            )
                        )
                    )
                )
                
            }
            
            let entityOffset = entityOffset_now
            body.execute(
                taskId: 0, 
                components: ( 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(
                            by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                        )
                    )
                )
            )
            // ############################################################################
            
        }

        let pageIdx = now_pageIdx

        var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
        var pageMask2 = SparseSet_L2_BaseMask
        var pageMask3 = UInt64(0)
        repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
        var pageMask = pageMask1 & pageMask2 & (~pageMask3)

        // ############################################################################
        if pageMask == 0 { continue }
        var slotIdx_now = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        var entityOffset_now = (pageIdx << 6) + slotIdx_now
        
        while pageMask != 0 {
            let entityOffset = entityOffset_now

            slotIdx_now = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            entityOffset_now = (pageIdx << 6) + slotIdx_now

            body.execute(
                taskId: 0, 
                components: ( 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(
                            by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                        )
                    )
                )
            )
            
        }
        
        let entityOffset = entityOffset_now
        body.execute(
            taskId: 0, 
            components: ( 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(
                        by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                    )
                )
            )
        )
        // ############################################################################
    }

    var blockMask = blockMask_now
    let dataPtrs = dataPtrs_now
    let pagePtrs = pagePtrs_now
    let wt_pagePtrs = wt_pagePtrs_now
    let wot_allSegment = wot_allSegment_now
    let blockIdx = segmentIndex_now
    let sparsePtrs = sparsePtrs_now

    // ###################################################### Sparse_Set_L2_i
    var now_pageIdx = blockMask.trailingZeroBitCount
    blockMask &= (blockMask - 1) 

    while blockMask != 0 { 
        let pageIdx = now_pageIdx
        now_pageIdx = blockMask.trailingZeroBitCount
        blockMask &= (blockMask - 1)

        var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
        var pageMask2 = SparseSet_L2_BaseMask
        var pageMask3 = UInt64(0)
        repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
        repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
        var pageMask = pageMask1 & pageMask2 & (~pageMask3)

        // ############################################################################
        if pageMask == 0 { continue }
        var slotIdx_now = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        var entityOffset_now = (pageIdx << 6) + slotIdx_now
        
        while pageMask != 0 {
            let entityOffset = entityOffset_now

            slotIdx_now = pageMask.trailingZeroBitCount
            pageMask &= (pageMask - 1)
            entityOffset_now = (pageIdx << 6) + slotIdx_now

            body.execute(
                taskId: 0, 
                components: ( 
                    repeat ComponentProxy(
                        pointer: (each dataPtrs).advanced(
                            by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                        )
                    )
                )
            )
            
        }
        
        let entityOffset = entityOffset_now
        body.execute(
            taskId: 0, 
            components: ( 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(
                        by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                    )
                )
            )
        )
        // ############################################################################
    }

    let pageIdx = now_pageIdx

    var pageMask1 = entities_activeMaskPtr.advanced(by: (blockIdx << 6) + pageIdx).pointee
    var pageMask2 = SparseSet_L2_BaseMask
    var pageMask3 = UInt64(0)
    repeat pageMask1 &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee
    repeat pageMask2 &= (each wt_pagePtrs).ptr.advanced(by: pageIdx).pointee
    repeat pageMask3 |= ((each wot_allSegment).pointee.pageMasks[pageIdx])
    var pageMask = pageMask1 & pageMask2 & (~pageMask3)

    while pageMask != 0 {
        let slotIdx = pageMask.trailingZeroBitCount
        pageMask &= (pageMask - 1)
        let entityOffset = (pageIdx << 6) + slotIdx
        body.execute(
            taskId: 0, 
            components: ( 
                repeat ComponentProxy(
                    pointer: (each dataPtrs).advanced(
                        by: Int((each sparsePtrs).ptr.advanced(by: entityOffset).pointee.compArrIdx)
                    )
                )
            )
        )
    }

    // ###################################################### Sparse_Set_L2_i

    repeat _fixLifetime(each storages)
    repeat _fixLifetime(each wt_storages)
    repeat _fixLifetime(each wot_storages)
    _fixLifetime(entities)
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











    // var i = global_First
    // if scanSegmentCount >= 4 {
    //     let unrolledLast = global_Last - 3
    //     while i <= unrolledLast {
    //         let i0 = i
    //         let i1 = i + 1
    //         let i2 = i + 2
    //         let i3 = i + 3
    //         var segmentMask4 = SIMD4<UInt64>(repeating: SparseSet_L2_BaseMask)

    //         repeat segmentMask4 &= SIMD4<UInt64>(
    //             (each allSegments).advanced(by: i0).pointee.pointee.blockMask,
    //             (each allSegments).advanced(by: i1).pointee.pointee.blockMask,
    //             (each allSegments).advanced(by: i2).pointee.pointee.blockMask,
    //             (each allSegments).advanced(by: i3).pointee.pointee.blockMask
    //         )

    //         repeat segmentMask4 &= SIMD4<UInt64>(
    //             (each wt_allSegments).advanced(by: i0).pointee.pointee.blockMask,
    //             (each wt_allSegments).advanced(by: i1).pointee.pointee.blockMask,
    //             (each wt_allSegments).advanced(by: i2).pointee.pointee.blockMask,
    //             (each wt_allSegments).advanced(by: i3).pointee.pointee.blockMask
    //         )

    //         if segmentMask4[0] != 0 {
    //             viewPlans.append(ViewPlan(segmentIndex: i0, mask: segmentMask4[0]))
    //         }
    //         if segmentMask4[1] != 0 {
    //             viewPlans.append(ViewPlan(segmentIndex: i1, mask: segmentMask4[1]))
    //         }
    //         if segmentMask4[2] != 0 {
    //             viewPlans.append(ViewPlan(segmentIndex: i2, mask: segmentMask4[2]))
    //         }
    //         if segmentMask4[3] != 0 {
    //             viewPlans.append(ViewPlan(segmentIndex: i3, mask: segmentMask4[3]))
    //         }

    //         i += 4
    //     }
    // }

    // while i <= global_Last {
    //     var segment_i_mask = SparseSet_L2_BaseMask
    //     repeat segment_i_mask &= (each allSegments).advanced(by: i).pointee.pointee.blockMask
    //     repeat segment_i_mask &= (each wt_allSegments).advanced(by: i).pointee.pointee.blockMask

    //     if segment_i_mask != 0 {
    //         viewPlans.append(ViewPlan(segmentIndex: i, mask: segment_i_mask))
    //     }
    //     i += 1
    // }

    // // --- 優化核心：Unroll 4 + Independent Dependency Chains ---
    // var i = global_First

    // if scanSegmentCount >= 4 {
    //     let unrolledLast = global_Last - 3
    //     while i <= unrolledLast {
    //         // 定義 4 個獨立的累積器，斷開相依鏈
    //         var m0 = SparseSet_L2_BaseMask
    //         var m1 = SparseSet_L2_BaseMask
    //         var m2 = SparseSet_L2_BaseMask
    //         var m3 = SparseSet_L2_BaseMask

    //         // 提前取出指針地址 (Peeling addresses)
    //         // 現代 CPU 的 AGU 可以同時算出這四個地址
    //         let base_i = i
            
    //         // 利用 Parameter Packs 暴力展開。
    //         // 這裡不使用 SIMD 構造函數，避免裝箱開銷，直接讓 CPU 的多個 ALU 並行運算。
    //         repeat (m0 &= (each allSegments).advanced(by: base_i).pointee.pointee.blockMask)
    //         repeat (m1 &= (each allSegments).advanced(by: base_i + 1).pointee.pointee.blockMask)
    //         repeat (m2 &= (each allSegments).advanced(by: base_i + 2).pointee.pointee.blockMask)
    //         repeat (m3 &= (each allSegments).advanced(by: base_i + 3).pointee.pointee.blockMask)

    //         repeat (m0 &= (each wt_allSegments).advanced(by: base_i).pointee.pointee.blockMask)
    //         repeat (m1 &= (each wt_allSegments).advanced(by: base_i + 1).pointee.pointee.blockMask)
    //         repeat (m2 &= (each wt_allSegments).advanced(by: base_i + 2).pointee.pointee.blockMask)
    //         repeat (m3 &= (each wt_allSegments).advanced(by: base_i + 3).pointee.pointee.blockMask)

    //         // 批次檢查並寫入。雖然有分支，但對於空資料，CPU 的分支預測器極強。
    //         // 且這段代碼的記憶體訪問是非常連續的 (Cache-friendly)
    //         if m0 != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i, mask: m0)) }
    //         if m1 != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i + 1, mask: m1)) }
    //         if m2 != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i + 2, mask: m2)) }
    //         if m3 != 0 { viewPlans.append(ViewPlan(segmentIndex: base_i + 3, mask: m3)) }

    //         i += 4
    //     }
    // }

    // // 4. 處理剩餘的邊界
    // while i <= global_Last {
    //     var mask = SparseSet_L2_BaseMask
    //     repeat mask &= (each allSegments).advanced(by: i).pointee.pointee.blockMask
    //     repeat mask &= (each wt_allSegments).advanced(by: i).pointee.pointee.blockMask

    //     if mask != 0 {
    //         viewPlans.append(ViewPlan(segmentIndex: i, mask: mask))
    //     }
    //     i += 1
    // }
