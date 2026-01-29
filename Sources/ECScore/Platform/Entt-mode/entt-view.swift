let SparseSet_L2_BaseMask: UInt64 = 0xFFFFFFFFFFFFFFFF

extension SparseSet_L2 {
    @inlinable
    func block_MaskOut_With(blockMask: inout UInt64) {
        blockMask &= sparse.blockMask
    }

    @inlinable
    func block_MaskOut_NotWith(blockMask: inout UInt64) {
        blockMask &= ~sparse.blockMask
    }

    @inlinable // should: 0 <= i <= 63
    func page_I_MaskOut_With(pageMask: inout UInt64, _ i: Int) {
        pageMask &= sparse.pageOnBlock[i].pageMask
    }

    @inlinable // should: 0 <= i <= 63
    func page_I_MaskOut_NotWith(pageMask: inout UInt64, _ i: Int) {
        pageMask &= ~sparse.pageOnBlock[i].pageMask
    }
}

func getStorages<each T>(
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ tokens: borrowing (repeat TypeToken<each T>)
) -> (repeat PFStorageBox<each T>)
{
    (repeat (each tokens).getStorage(base: base))
}

func getMinimum_ActiveMemberNumber_OfStorages<each T>(
    _ storages: borrowing (repeat PFStorageBox<each T>)
) -> Int 
{
    var minimum = Int.max
    for storage in repeat each storages {
        minimum = min(minimum, storage.activeEntityCount)
    }
    return minimum
}

func getMinimum_LastActiveSection_OfStorages<each T>(
    _ storages: borrowing (repeat PFStorageBox<each T>)
) -> Int 
{
    var minimum = Int.max
    for storage in repeat each storages {
        minimum = min(minimum, storage.lastActiveSegment)
    }
    return minimum
}

func getMaximum_FirstActiveSection_OfStorages<each T>(
    _ storages: borrowing (repeat PFStorageBox<each T>)
) -> Int 
{
    var maximum = Int.min
    for storage in repeat each storages {
        maximum = max(maximum, storage.firstActiveSegment)
    }
    return maximum
}

struct ViewPlan {
    let segmentIndex: Int
    let mask: UInt64
}

@inline(__always)
func createViewPlans<each T>( 
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>)
) -> [ViewPlan]
{
    let storages: (repeat PFStorageBox<each T>) = (repeat (each with).getStorage(base: base))
    var global_First = Int.min; repeat maxHelper(&global_First, (each storages).firstActiveSegment);
    var global_Last = Int.max; repeat minHelper(&global_Last, (each storages).lastActiveSegment);
    if global_First > global_Last { return [] }
    
    var global_Minimum_ActiveSegmentCount = Int.max; repeat minHelper(&global_Minimum_ActiveSegmentCount, (each storages).activeSegmentCount);
    var viewPlans = [ViewPlan]()
    let estimated_space = min(global_Minimum_ActiveSegmentCount, global_Last - global_First + 1)
    viewPlans.reserveCapacity(estimated_space)

    for i in stride(from: global_First, through: global_Last, by: 1) {
        var segment_i_mask = SparseSet_L2_BaseMask
        repeat (each storages).segmentBlockMaskWith(mask: &segment_i_mask, i)
        if segment_i_mask != 0 {
            viewPlans.append(ViewPlan(segmentIndex: i, mask: segment_i_mask)) 
        }
    }

    return viewPlans
}

@inline(__always)
func executeViewPlans<each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    viewPlans: [ViewPlan],
    with: borrowing (repeat TypeToken<each T>),
    _ action: ( (repeat UnsafeMutablePointer<each T> ) -> Void)
) {
    let storages: (repeat PFStorageBox<each T>) = (repeat (each with).getStorage(base: base))
    
    for vp in viewPlans { 
        var blockMask = vp.mask    
        let dataPtrs = (repeat (each storages).get_SparseSetL2MutPointer_Uncheck(vp.segmentIndex))
        let pagePtrs = (repeat (each storages).getSparsePagePointer_Uncheck(vp.segmentIndex))
        
    while blockMask != 0 {
        let pageIdx = blockMask.trailingZeroBitCount
        let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))

        var pageMask = SparseSet_L2_BaseMask;
        repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask

        while pageMask != 0 {
            let slotIdx = pageMask.trailingZeroBitCount // 0 ~ 63
            let compArrIdxs = (repeat (each entityOnPagePtrs).getSlotCompArrIdx_Uncheck(slotIdx))
            
            // logic here
            action( repeat (each dataPtrs).advanced(by: (each compArrIdxs).idx) )
            
            // end
            pageMask &= (pageMask - 1)
        }
        // end
        blockMask &= (blockMask - 1)
    }}
}

@inline(__always)
func minHelper(_ minimum: inout Int, _ new: borrowing Int) {
    minimum = min(minimum, new)
}

@inline(__always)
func maxHelper(_ maximum: inout Int, _ new: borrowing Int) {
    maximum = max(maximum, new)
}

