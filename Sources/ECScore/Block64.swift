struct Block64_L2 { // Layer 2
    private(set) var blockMask: UInt64 = 0
    private(set) var activePageCount: Int = 0
    private(set) var activeEntityCount: Int = 0
    private(set) var pageOnBlock = 
        ContiguousArray<Page64>(repeating: Page64(), count: 64)

    @inline(__always)
    private mutating func addPage(_ bit: UInt64) {
        // precondition(index >= 0 && index < 64, "invalid Block64_L2 index")
        // let bit = UInt64(1) << index
        // precondition(blockMask & bit == 0, "double add Page to Block64_L2")
        
        blockMask |= bit
        activePageCount += 1
    }

    @inline(__always)
    private mutating func removePage(_ bit: UInt64) {
        // precondition(index >= 0 && index < 64, "invalid Page64 index")
        // let bit = UInt64(1) << index
        // precondition(blockMask & bit != 0, "remove inactive slot")
        
        blockMask &= ~bit
        activePageCount -= 1
        let index = bit.trailingZeroBitCount
        activeEntityCount -= pageOnBlock[index].activeCount
        pageOnBlock[index].reset()
    }

    @inline(__always)
    mutating func addEntityOnBlock(_ index: Int, ssEntry: SparseSetEntry) {
        let (blockId, pageId) = (index >> 6, index & 63)

        // check whether or not blockId is in 0~63
        precondition(blockId >= 0 && blockId < 64, "invalid Block64_L2 index")
        let bit = UInt64(1) << blockId
        if blockMask & bit == 0 { addPage(bit)  } // active page

        pageOnBlock[blockId].add(pageId, ssEntry) // fn will check whether or not pageId is in 0~63
        activeEntityCount += 1
    }

    @inline(__always)
    mutating func removeEntityOnBlock(_ index: Int, ssEntry: SparseSetEntry) {
        let (blockId, pageId) = (index >> 6, index & 63)

        precondition(blockId >= 0 && blockId < 64, "invalid Block64_L2 index")        
        let bit = UInt64(1) << blockId
        precondition(blockMask & bit != 0, "remove entity on inactive page")

        pageOnBlock[blockId].remove(pageId) // fn will check whether or not pageId is in 0~63
        activeEntityCount -= 1
        if pageOnBlock[blockId].activeCount == 0 { removePage(bit) }
    }

    @inline(__always)
    func getUnchecked(_ index: Int) -> SparseSetEntry {
        let (blockId, pageId) = (index >> 6, index & 63)
        return pageOnBlock[blockId].getUnchecked(pageId)
    }

    public func contains(_ index: Int) -> Bool {
        let pageIdx = index >> 6   // offset / 64
        let bit = UInt64(1) << pageIdx
        guard (blockMask & bit) != 0 else { return false }
        
        let slotIdx = index & 0x3F // offset % 64
        return pageOnBlock[pageIdx].get(slotIdx) != nil
    }


    // @inline(__always)
    // func getPagesMask(mask: UInt64) -> [UInt64] {
    //     var ret: [UInt64] = []
    //     var temp = mask
    //     while temp != 0 {
    //         let index = temp.trailingZeroBitCount
    //         ret.append(pageOnBlock[index].pageMask)
    //         temp &= ~(1 << index)
    //     }
    //     return ret
    // }

    // @inline(__always)
    // func forEachEntity(action: (Int) -> Void) {
    //     var bMask = self.blockMask
    //     while bMask != 0 {
    //         let bIdx = bMask.trailingZeroBitCount
    //         let baseId = bIdx << 6 // 算出 ID 的基礎偏移量 (bIdx * 64)
            
    //         var pMask = pageOnBlock[bIdx].pageMask
    //         while pMask != 0 {
    //             let pIdx = pMask.trailingZeroBitCount
    //             action(baseId | pIdx) // 組合出真正的 Entity ID
    //             pMask &= (pMask - 1)
    //         }
    //         bMask &= (bMask - 1)
    //     }
    // }
}
