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
    func page_I_MaskOut_With(pageMask: inout UInt64, i: Int) {
        pageMask &= sparse.pageOnBlock[i].pageMask
    }
    @inlinable // should: 0 <= i <= 63
    func page_I_MaskOut_NotWith(pageMask: inout UInt64, i: Int) {
        pageMask &= ~sparse.pageOnBlock[i].pageMask
    }
}

func getMinimum_ActiveMember_NumberOfStorages<each T>(
    _ storage: borrowing (repeat PFStorageBox<each T>)
) -> Int 
{
    var minimum: Int = Int.max
    repeat minHelper(minimum: &minimum, new: (each storage).activeEntityCount)
    return minimum
}

func getMinimum_Section_NumberOfStorages<each T>(
    _ storage: borrowing (repeat PFStorageBox<each T>)
) -> Int 
{
    var minimum: Int = Int.max
    repeat minHelper(minimum: &minimum, new: (each storage).segmentCount)
    return minimum
}


@inline(__always)
private func minHelper(minimum: inout Int, new: Int) {
    minimum = min(minimum, new)
}
