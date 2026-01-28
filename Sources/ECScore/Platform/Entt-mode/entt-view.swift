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
