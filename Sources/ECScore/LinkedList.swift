fileprivate let SENTINEL = BlockOffset(4096) // 使用 4096 作為哨兵節點索引
fileprivate let NIL = BlockOffset(-1)
fileprivate let EMPTY = BlockOffset(-2)

final class LinkedList4096 {
    // prev/next 陣列長度改為 4097，最後一個位置 [4096] 是哨兵
    private(set) var prev = ContiguousArray<BlockOffset>(repeating: NIL, count: 4097)
    private(set) var next = ContiguousArray<BlockOffset>(repeating: NIL, count: 4097)

    init() {
        // 初始化：哨兵節點指向自己，形成一個閉環
        prev[Int(SENTINEL)] = SENTINEL
        next[Int(SENTINEL)] = SENTINEL
    }

    var head: BlockOffset { 
        // 如果哨兵的下一個還是自己，代表鏈表是「空的」
        next[Int(SENTINEL)] == SENTINEL ?
        EMPTY : // 返回你原始定義的空表標誌
        next[Int(SENTINEL)] // 否則返回真正的第一個節點索引
    }

    var tail: BlockOffset { 
        prev[Int(SENTINEL)] == SENTINEL ?
        EMPTY : 
        prev[Int(SENTINEL)] 
    }

    var isEmpty: Bool {
        return head == EMPTY
    }
    
    func add(_ index: Int) {
        // 1. 重複添加檢查
        guard prev[index] == NIL && next[index] == NIL else { return }
        guard index >= 0 && index < 4096 else { return }    
        
        let node = BlockOffset(index)
        let oldTail = prev[Int(SENTINEL)] // 哨兵的 prev 就是 tail

        // 2. 核心邏輯：插入到 oldTail 與 SENTINEL 之間
        // [oldTail] <-> [SENTINEL]  變為  [oldTail] <-> [node] <-> [SENTINEL]
        prev[index] = oldTail
        next[index] = SENTINEL
        
        next[Int(oldTail)] = node
        prev[Int(SENTINEL)] = node
    }

    func remove(_ index: Int) {
        let p = prev[index]
        let n = next[index]

        // 1. 存在性檢查
        guard p != NIL && n != NIL else { return }

        // 2. 核心邏輯：直接連通前後，完全不需要 if-else 判斷 head/tail
        next[Int(p)] = n
        prev[Int(n)] = p

        // 3. 重置狀態
        prev[index] = NIL
        next[index] = NIL
    }

    func contains(_ index: Int) -> Bool {
        // 注意：index 必須在 0..<4096 範圍內，SENTINEL 本身不計入
        return index < 4096 && prev[index] != NIL
    }

    func addOrMoveToTail(_ index: Int) {
        remove(index)
        add(index)
    }

    func reset() {
        // 使用內建的 withUnsafeMutableBufferPointer 是最接近 C 語言速度的作法
        // 它能保證不產生多餘的拷貝
        prev.withUnsafeMutableBufferPointer { $0.initialize(repeating: NIL) }
        next.withUnsafeMutableBufferPointer { $0.initialize(repeating: NIL) }
        
        // 重新接回哨兵
        prev[Int(SENTINEL)] = SENTINEL
        next[Int(SENTINEL)] = SENTINEL
    }
    
}
