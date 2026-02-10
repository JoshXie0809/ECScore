// struct Block64_L2 { // Layer 2
//     @inline(__always) private(set) var blockMask: UInt64 = 0
//     @inline(__always) private(set) var activePageCount: Int = 0
//     @inline(__always) private(set) var activeEntityCount: Int = 0
//     @inline(__always) private(set) var pageOnBlock = 
//         ContiguousArray<Page64>(repeating: Page64(), count: 64)

//     @inline(__always)
//     private mutating func addPage(_ bit: UInt64) {
//         // precondition(index >= 0 && index < 64, "invalid Block64_L2 index")
//         // let bit = UInt64(1) << index
//         // precondition(blockMask & bit == 0, "double add Page to Block64_L2")
        
//         blockMask |= bit
//         activePageCount += 1
//     }

//     @inline(__always)
//     private mutating func removePage(_ bit: UInt64) {
//         // precondition(index >= 0 && index < 64, "invalid Page64 index")
//         // let bit = UInt64(1) << index
//         // precondition(blockMask & bit != 0, "remove inactive slot")
        
//         blockMask &= ~bit
//         activePageCount -= 1
//         let index = bit.trailingZeroBitCount
//         activeEntityCount -= pageOnBlock[index].activeCount
//         pageOnBlock[index].reset()
//     }

//     @inline(__always)
//     mutating func addEntityOnBlock(_ index: Int, ssEntry: SparseSetEntry) {
//         let (pageIdx, slotIdx) = (index >> 6, index & 63)

//         // check whether or not blockId is in 0~63
//         assert(pageIdx >= 0 && pageIdx < 64, "invalid Block64_L2 index")
//         let bit = UInt64(1) << pageIdx
//         if blockMask & bit == 0 { addPage(bit)  } // active page

//         pageOnBlock[pageIdx].add(slotIdx, ssEntry) // fn will check whether or not pageId is in 0~63
//         activeEntityCount += 1
//     }

//     @inline(__always)
//     mutating func removeEntityOnBlock(_ index: Int) {
//         let (pageIdx, slotIdx) = (index >> 6, index & 63)
//         assert(pageIdx >= 0 && pageIdx < 64, "invalid Block64_L2 index")
//         let bit = UInt64(1) << pageIdx
//         assert(blockMask & bit != 0, "remove entity on inactive page")

//         pageOnBlock[pageIdx].remove(slotIdx) // fn will check whether or not pageId is in 0~63
//         activeEntityCount -= 1
//         if pageOnBlock[pageIdx].activeCount == 0 { removePage(bit) }
//     }

//     @inline(__always)
//     func getUnchecked(_ index: Int) -> SparseSetEntry {
//         let (pageIdx, slotIdx) = (index >> 6, index & 63)
//         return pageOnBlock[pageIdx].getUnchecked(slotIdx)
//     }

//     @inline(__always)
//     func contains(_ index: Int) -> Bool {
//         let pageIdx = index >> 6   // offset / 64
//         let bit = UInt64(1) << pageIdx
//         guard (blockMask & bit) != 0 else { return false }
        
//         let slotIdx = index & 0x3F // offset % 64
//         return pageOnBlock[pageIdx].get(slotIdx) != nil
//     }

//     @inline(__always)
//     mutating func updateComponentArrayIdx(_ index: Int, _ updateFn: (inout SparseSetEntry) -> Void ) {
//         let (pageIdx, slotIdx) = (index >> 6, index & 63)

//         assert(pageIdx >= 0 && pageIdx < 64, "invalid Block64_L2 index")        
//         let bit = UInt64(1) << pageIdx
//         assert(blockMask & bit != 0, "update entity on inactive page")

//         pageOnBlock[pageIdx].update(slotIdx, updateFn)
//     }


//     // @inline(__always)
//     // func getPagesMask(mask: UInt64) -> [UInt64] {
//     //     var ret: [UInt64] = []
//     //     var temp = mask
//     //     while temp != 0 {
//     //         let index = temp.trailingZeroBitCount
//     //         ret.append(pageOnBlock[index].pageMask)
//     //         temp &= ~(1 << index)
//     //     }
//     //     return ret
//     // }

//     // @inline(__always)
//     // func forEachEntity(action: (Int) -> Void) {
//     //     var bMask = self.blockMask
//     //     while bMask != 0 {
//     //         let bIdx = bMask.trailingZeroBitCount
//     //         let baseId = bIdx << 6 // 算出 ID 的基礎偏移量 (bIdx * 64)
            
//     //         var pMask = pageOnBlock[bIdx].pageMask
//     //         while pMask != 0 {
//     //             let pIdx = pMask.trailingZeroBitCount
//     //             action(baseId | pIdx) // 組合出真正的 Entity ID
//     //             pMask &= (pMask - 1)
//     //         }
//     //         bMask &= (bMask - 1)
//     //     }
//     // }
// }
