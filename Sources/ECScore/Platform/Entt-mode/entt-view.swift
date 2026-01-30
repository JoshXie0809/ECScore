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
) -> ContiguousArray<ViewPlan>
{
    let storages: (repeat PFStorageBox<each T>) = (repeat (each with).getStorage(base: base))
    var global_First = Int.min; repeat maxHelper(&global_First, (each storages).firstActiveSegment);
    var global_Last = Int.max; repeat minHelper(&global_Last, (each storages).lastActiveSegment);
    if global_First > global_Last { return [] }
    
    var global_Minimum_ActiveSegmentCount = Int.max; repeat minHelper(&global_Minimum_ActiveSegmentCount, (each storages).activeSegmentCount);
    var viewPlans = ContiguousArray<ViewPlan>()
    let estimated_space = min(global_Minimum_ActiveSegmentCount, global_Last - global_First + 1)
    viewPlans.reserveCapacity(estimated_space)
    let allSegments = (repeat (each storages).segments)
    for i in stride(from: global_First, through: global_Last, by: 1) {
        var segment_i_mask = SparseSet_L2_BaseMask
        repeat segment_i_mask &= (each allSegments).advanced(by: i).pointee?.sparse.blockMask ?? 0
        if segment_i_mask != 0 {
            viewPlans.append(ViewPlan(segmentIndex: i, mask: segment_i_mask)) 
        }
    }
    
    repeat _fixLifetime(each storages)
    return viewPlans
}

@inline(__always)
func executeViewPlans<each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    viewPlans: ContiguousArray<ViewPlan>,
    with: borrowing (repeat TypeToken<each T>),
    _ action: (_ taskId: Int, _ pack: repeat UnsafeMutablePointer<each T>) -> Void
) {
    let storages: (repeat PFStorageBox<each T>) = (repeat (each with).getStorage(base: base))

    for vp in viewPlans {
        var blockMask = vp.mask
        let dataPtrs = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(vp.segmentIndex))
        let pagePtrs = (repeat (each storages).getSparseSetL2_PagePointer_Uncheck(vp.segmentIndex))
        
        // ###################################################### Sparse_Set_L2_i
        while blockMask != 0 { 
            let pageIdx = blockMask.trailingZeroBitCount
            let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
            var pageMask = SparseSet_L2_BaseMask
            repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask

            while pageMask != 0 { 
                let slotIdx = pageMask.trailingZeroBitCount
                // do action here
                // ############################################################################
                action(0, repeat (each dataPtrs).advanced(by: (each entityOnPagePtrs).getSlotCompArrIdx_Uncheck( slotIdx )) )
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
}

@inline(__always)
func view<each T> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    _ action: (_ taskId: Int, _ pack: repeat UnsafeMutablePointer<each T>) -> Void
) {
    let vps = createViewPlans( base: base, with: (repeat each with) )
    executeViewPlans(base: base, viewPlans: vps, with: (repeat each with), action)
}


@inline(__always)
func minHelper(_ minimum: inout Int, _ new: borrowing Int) {
    minimum = min(minimum, new)
}

@inline(__always)
func maxHelper(_ maximum: inout Int, _ new: borrowing Int) {
    maximum = max(maximum, new)
}

@inline(__always)
func executeViewPlansParallel<each T: Sendable>(
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    viewPlans: ContiguousArray<ViewPlan>,
    with: borrowing (repeat TypeToken<each T>),
    coresNum: Int,
    _ action: @escaping @Sendable (_ taskId: Int, _ pack: repeat UnsafeMutablePointer<each T>) -> Void
) async {
    let processorCount = min(ProcessInfo.processInfo.activeProcessorCount, coresNum)
    let planCount = viewPlans.count
    if planCount < processorCount || planCount < 8 {
        executeViewPlans(base: base, viewPlans: viewPlans, with: (repeat each with), action)
        return
    }

    let storages = (repeat (each with).getStorage(base: base))
    await withTaskGroup(of: Void.self) { group in
        let chunkSize = (planCount + processorCount - 1) / processorCount
        for i in stride(from: 0, to: planCount, by: chunkSize) {
            let range = i..<min(i + chunkSize, planCount)
            let chunk = Array(viewPlans[range])
            let taskId = i / chunkSize
            // ##################################################################################### core task
            group.addTask {
                // 每個 Task 處理一組獨立的 Segments
                for vp in chunk {
                    var blockMask = vp.mask
                    let dataPtrs = (repeat (each storages).get_SparseSetL2_CompMutPointer_Uncheck(vp.segmentIndex))
                    let pagePtrs = (repeat (each storages).getSparseSetL2_PagePointer_Uncheck(vp.segmentIndex))

                    // ##################################################################################### Sparse_Set_L2_i
                    while blockMask != 0 {
                        let pageIdx = blockMask.trailingZeroBitCount
                        let entityOnPagePtrs = (repeat (each pagePtrs).getEntityOnPagePointer_Uncheck(pageIdx))
                        var pageMask = SparseSet_L2_BaseMask
                        repeat pageMask &= (each pagePtrs).ptr.advanced(by: pageIdx).pointee.pageMask

                        while pageMask != 0 {
                            let slotIdx = pageMask.trailingZeroBitCount
                            action( 
                                taskId,
                                repeat (each dataPtrs).advanced(by: (each entityOnPagePtrs).getSlotCompArrIdx_Uncheck(slotIdx))
                            )
                            pageMask &= (pageMask - 1)
                        }
                        blockMask &= (blockMask - 1)
                    }
                    // ##################################################################################### Sparse_Set_L2_i

                }
            }
            // ##################################################################################### core task
        }
    }
    repeat _fixLifetime(each storages)
}

@inline(__always)
func viewParallel<each T: Sendable> (
    base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    with: borrowing (repeat TypeToken<each T>),
    coresNum: Int = 4,
    _ action: @escaping @Sendable (_ taskId: Int, _ pack: repeat UnsafeMutablePointer<each T>) -> Void
) async {
    let vps = createViewPlans( base: base, with: (repeat each with) )
    await executeViewPlansParallel(base: base, viewPlans: vps, with: (repeat each with), coresNum: coresNum, action)
}

struct ViewPack<each T: Component>: ~Copyable {
    // 將所有 Storage 放在一個元組裡
    var data: (repeat UnsafeMutablePointer<each T>)
    fileprivate init(_ data: (repeat UnsafeMutablePointer<each T>)) { self.data = data }
}
