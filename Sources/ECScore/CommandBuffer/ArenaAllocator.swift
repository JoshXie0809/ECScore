final class ArenaAllocator {
    private let start: UnsafeMutableRawPointer
    private let capacity: Int
    private var offset: Int = 0

    init(capacity: Int) {
        self.capacity = capacity
        self.start = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 8)
    }

    deinit {
        start.deallocate()
    }

    func alloc(size: Int, alignment: Int) -> UnsafeMutableRawPointer? {
        let currentAddress = Int(bitPattern: start + offset)
        let alignedAddress = (currentAddress + (alignment - 1)) & ~(alignment - 1)
        let newOffset = alignedAddress - Int(bitPattern: start) + size

        guard (newOffset <= capacity) else {
            // Out of memory
            return nil
        }

        let result = start + newOffset - size
        offset = newOffset
        return result
    }

    func reset() {
        offset = 0
    }

}

class PageNode<T> {
    let allocator = ArenaAllocator(capacity: 1024 * 16) // 16 KB
    let alignment = MemoryLayout<T>.alignment
    let size = MemoryLayout<T>.size
    
    func add(_ new: T) -> UnsafeMutablePointer<T> {
        guard let ptr = allocator.alloc(size: self.size, alignment: self.alignment)?.bindMemory(to: T.self, capacity: 1) else {
            // 測試所以粗暴一點
            fatalError()
        }

        ptr.initialize(to: new)
        return ptr
    }

}