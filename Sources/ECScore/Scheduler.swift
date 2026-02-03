import Foundation

struct Scheduler {

}

typealias MASKS = ContiguousArray<MASK>
typealias MASK = ContiguousArray<UInt64>

extension MASK {
    @inline(__always)
    static func createMask(_ maxRid: Int) -> MASK {
        MASK(repeating: 0, count: (maxRid >> 6) + 1)
    }

    @inline(__always)
    mutating func wear(_ ridId: Int ) {
        self.withUnsafeMutableBufferPointer { myself in
            // 1. 找到在哪個 UInt64 分段 (ridId / 64)
            // 2. 產生位元遮罩 (1 << (ridId % 64))
            myself.baseAddress![ridId >> 6] |= (1 << (ridId & 63))
        }
    }
}

typealias MASK_ID = Int
extension MASK {
    @inline(__always)
    mutating func mask_CAN_WEAR_RIDS(_ rids: [Int]) -> Bool {
        // 將迴圈包在 BufferPointer 裡面，只進入一次記憶體受保護區塊
        let hasCollision = self.withUnsafeBufferPointer { myself in
            for ridId in rids {
                let wordIdx = ridId >> 6
                let bitIdx = ridId & 63
                // 使用位元與運算，只要不是 0 就是衝突
                if (myself.baseAddress![wordIdx] & (1 << bitIdx)) != 0 {
                    return true 
                }
            }
            return false
        }

        if !hasCollision {
            // 沒衝突才進行 wear
            for ridId in rids { self.wear(ridId) } 
            return true
        }
        
        return false
    }
}


extension MASKS {
    @inline(__always)
    mutating func MASKS_CAN_WEAR_RIDS( _ rids: [Int], _ start: Int = 0) -> MASK_ID?
    {
        let count = self.count
        if start >= count  { return nil }
        var res: Bool = false
        
        return self.withUnsafeMutableBufferPointer { myself in
            for i in start..<count {
                res = myself.baseAddress![i].mask_CAN_WEAR_RIDS(rids)
                if res == true { return i }
            }
            
            return nil
        }
    }
}

func scheduler(_ base : borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>, _ RIDSs: [Int]...) {
    // let maxRid = base.registry.maxRidId
    // assume is 109 (count = 110)
    let maxRid = 109
    var Masks = MASKS()
    var systemStore = [[Int]]()
    var startAddedIdx = 0

    for (system_i, rids) in RIDSs.enumerated() {
        print("before", Masks)
        let res = Masks.MASKS_CAN_WEAR_RIDS(rids, startAddedIdx) // true: added immediately

        if res == nil {
            var mask = MASK.createMask(maxRid)
            for rid in rids { mask.wear(rid) }
            Masks.append( mask )
            systemStore.append([system_i])
        } else {
            systemStore[res!].append(system_i)
            // check
            if systemStore[startAddedIdx].count >= 2 { startAddedIdx += 1}
        }

        print("wear: ", rids)
        print("can wear at \(res ?? -1)")
        print("after", Masks)
        print("systemStore", systemStore)
        print("======")
        
    }
}


extension MASK {
    // 判斷該 Mask 裡的位元是否已經太過擁擠
    @inline(__always)
    func isSaturated(_ tolerenceCount: Int) -> Bool {
        return self.withUnsafeBufferPointer { myself in
            var setBits = 0
            for i in 0..<self.count {
                // 使用內建的位元計數功能，極速計算有幾個位元是 1
                setBits += myself.baseAddress![i].nonzeroBitCount
            }
            // 假設總資源 ID 是 110 個，如果佔用了超過 70% (80)，就視為飽和
            return setBits > tolerenceCount 
        }
    }
}

let _SCHEDULER2_TOLERENCE_RATE = 0.5
let _SCHEDULER2_MAX_SYSTEMS_PER_LAYER_DEVIDER = 4


func scheduler2(_ base : borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>, _ RIDSs: [[Int]]) -> [[Int]] {
    let maxRid = 109
    let tolerenceCount = Int(Double(maxRid + 1) * _SCHEDULER2_TOLERENCE_RATE)
    var Masks = MASKS()
    var systemStore = [[Int]]()
    var startAddedIdx = 0 // 核心水位線
    let MAX_SYSTEMS_PER_LAYER = max(1, ProcessInfo.processInfo.activeProcessorCount / _SCHEDULER2_MAX_SYSTEMS_PER_LAYER_DEVIDER)

    for (system_i, rids) in RIDSs.enumerated() {
        // 從水位線開始找，自動跳過前面已經「確定滿了」的 Masks
        let res = Masks.MASKS_CAN_WEAR_RIDS(rids, startAddedIdx)

        if let foundIdx = res {
            systemStore[foundIdx].append(system_i)
        } else {
            // 沒地方塞，建立新層級
            var mask = MASK.createMask(maxRid)
            for rid in rids { mask.wear(rid) }
            Masks.append(mask)
            systemStore.append([system_i])
        }

        // 重要：如果當前水位線所在的層級塞滿了，就把水位線往後推
        // 這樣下一個系統進來，就永遠不會再去碰這個已經滿載的 Mask
        // 修改點：水位線應該在「數量滿了」或「位元滿了」時都往後推
        while startAddedIdx < systemStore.count && 
            (systemStore[startAddedIdx].count >= MAX_SYSTEMS_PER_LAYER || 
            Masks[startAddedIdx].isSaturated(tolerenceCount)) 
        {
            startAddedIdx += 1
        }

        // print("wear: ", rids)
        // print("can wear at \(res ?? -1)")
        // print("after", Masks)
        // print("systemStore", systemStore)
        // print("======")


    }

    return systemStore
}
