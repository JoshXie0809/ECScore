struct PFStorage<T: Component>: ~Copyable {
    // this is not nill version
    private(set) var segments: ContiguousArray<UnsafeMutablePointer<SparseSet_L2<T>>>
    private(set) var activeEntityCount = 0
    private(set) var firstActiveSegment: Int = Int.max
    private(set) var lastActiveSegment: Int = Int.min
    private(set) var activeSegmentCount: Int = 0

    public let sentinelPtr: UnsafeMutablePointer<SparseSet_L2<T>>

    var storageType: any Component.Type { T.self }
    var segmentCount : Int { segments.count }
    
    init() {
        self.sentinelPtr = UnsafeMutablePointer<SparseSet_L2<T>>.allocate(capacity: 1)
        self.sentinelPtr.initialize(to: SparseSet_L2<T>()) 
        
        self.segments = ContiguousArray()
        self.segments.reserveCapacity(1024) // init some place
    }

    deinit {
        for ptr in segments {
            // de-init not nil page
            if ptr != sentinelPtr {
                ptr.deinitialize(count: 1)
                ptr.deallocate()
            }
        }

        sentinelPtr.deinitialize(count: 1)
        sentinelPtr.deallocate()
    }

    @inline(__always)
    private func allocatePage() -> UnsafeMutablePointer<SparseSet_L2<T>> {
        let ptr = UnsafeMutablePointer<SparseSet_L2<T>>.allocate(capacity: 1)
        ptr.initialize(to: SparseSet_L2<T>())
        return ptr
    }

    // 輔助：釋放 Page
    @inline(__always)
    private func freePage(_ ptr: UnsafeMutablePointer<SparseSet_L2<T>>) {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }

    @inline(__always)
    private mutating func ensureCapacity(for eid: EntityId) -> Int {
        let blockIdx = Int(eid.id >> 12)
        if blockIdx >= segments.count {
            let needed = blockIdx - segments.count + 1
            segments.append(contentsOf: repeatElement(sentinelPtr, count: needed))
        }

        if segments[blockIdx] == sentinelPtr {
            segments[blockIdx] = allocatePage()
            activeSegmentCount += 1
            updateFirstLast_Add(blockIdx: blockIdx)
        }

        return blockIdx
    }

    @inline(__always)
    private mutating func updateFirstLast_Add(blockIdx: Int) {
        firstActiveSegment = min(firstActiveSegment, blockIdx)
        lastActiveSegment = max(lastActiveSegment, blockIdx)
    }

    @inline(__always)
    private mutating func updateFirstLast_Remove(blockIdx: Int) {
        if blockIdx == firstActiveSegment {
            for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1){
                if segments[i] != sentinelPtr {
                    firstActiveSegment = i
                    return
                } 
            }

            firstActiveSegment = Int.max
            lastActiveSegment = Int.min
        }
        else if blockIdx == lastActiveSegment {
            for i in stride(from: lastActiveSegment, through: firstActiveSegment, by: -1) {
                if segments[i] != sentinelPtr {
                    lastActiveSegment = i
                    return
                }
            }

            firstActiveSegment = Int.max
            lastActiveSegment = Int.min
        }
    }

    @inlinable
    mutating func add(eid: borrowing EntityId, component: consuming T) {
        let blockIdx = ensureCapacity(for: eid)

        assert(segments[blockIdx] != sentinelPtr, "using sentinelPtr in PFStorage.add") // for-debug
        let storagePtr = segments[blockIdx]
        
        let beforeCount = storagePtr.pointee.count
        storagePtr.pointee.add(eid, component)
        self.activeEntityCount += (storagePtr.pointee.count - beforeCount)
    }

    @inlinable
    mutating func remove(eid: borrowing EntityId) {
        let blockIdx = Int(eid.id >> 12)
        
        guard blockIdx < segments.count else { return }
        let storagePtr = segments[blockIdx]
        guard storagePtr != sentinelPtr else { return }

        let beforeCount = storagePtr.pointee.count
        storagePtr.pointee.remove(eid)
        self.activeEntityCount += (storagePtr.pointee.count - beforeCount)

        // if segment has no active member
        if storagePtr.pointee.count == 0 {
            freePage(storagePtr)
            // set as sentinel
            segments[blockIdx] = sentinelPtr   
            activeSegmentCount -= 1

            if activeSegmentCount == 0 {
                firstActiveSegment = Int.max
                lastActiveSegment = Int.min
            } else {
                updateFirstLast_Remove(blockIdx: blockIdx)
            }
        }
    }

    @inlinable
    func getWithDenseIndex_Uncheck_Typed(_ index: Int) -> T? {
        var temp_index = index
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
        {
            let segmentPtr = segments[i]
            if segmentPtr != sentinelPtr {
                let count = segmentPtr.pointee.count
                if temp_index >= count {
                    temp_index -= count
                    continue
                }
                return segmentPtr.pointee.components[temp_index]
            }
        }

        return nil
    }

    @inlinable
    func get(_ eid: borrowing EntityId) -> T? {
        let (blockIdx, offset) = (Int(eid.id >> 12), Int(eid.id & 4095))
        guard blockIdx < segments.count else { return nil }
        
        let ptr = segments[blockIdx]
        if ptr == sentinelPtr { return nil }        
        return ptr.pointee.get(offset: offset, version: eid.version)
    }

    @inlinable
    func getWithDenseIndex_Uncheck(_ index: Int) -> Any? {
        var temp_index = index
        for i in stride(from: firstActiveSegment, through: lastActiveSegment, by: 1) 
        {
            let segmentPtr = segments[i]
            if segmentPtr != sentinelPtr {
                let count = segmentPtr.pointee.count
                if temp_index >= count {
                    temp_index -= count
                    continue
                }
                return segmentPtr.pointee.components[temp_index]
            }
        }
        return nil
    }
    
    @inlinable
    func get(_ eid: borrowing EntityId) -> Any? {
        let (blockIdx, offset) = (eid.id >> 12, eid.id & 4095)
        guard blockIdx < segments.count else { return nil }
        let segmentPtr = segments[blockIdx]
        guard segmentPtr != sentinelPtr else {
            return nil
        }
        
        return segmentPtr.pointee.get(offset: offset, version: eid.version)
    }


    @inlinable
    mutating func rawAdd(eid: borrowing EntityId, component: consuming Any) {
        guard let typedComponent = component as? T else {
            fatalError("the type mismatched while using rawAdd")
        }
        self.add(eid: eid, component: typedComponent)
    }

    @inlinable
    mutating func getSegmentComponentsRawPointer_Internal(_ blockIdx: Int) -> UnsafeMutablePointer<T> {
        // 這裡使用 Unsafe 存取來繞過 mutating 限制
        // 既然你保證了 reserveCapacity，這是安全的
        // 直接回傳，呼叫者需確保該 Segment 有效
        return segments[blockIdx].pointee.getRawDataPointer() 
    }

    @inlinable
    func getSegmentsRawPointer_Internal() -> UnsafePointer<UnsafeMutablePointer<SparseSet_L2<T>>> {
        // 【核心優化成果】
        // 現在這裡回傳的是「指標的陣列」，而不是「Optional 的陣列」
        // 在 C 語言層面，這就是 T** (pointer to pointer)
        // 這是最適合 createViewPlans 進行無分支讀取的格式
        return segments.withUnsafeBufferPointer { $0.baseAddress! }    
    }
}