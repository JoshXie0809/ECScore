final class ArenaAllocator {
    private let start: UnsafeMutableRawPointer
    private let capacity: Int
    private var offset: Int = 0

    init(capacity: Int, alignment: Int) {
        self.capacity = capacity
        self.start = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: alignment)
    }

    deinit {
        start.deallocate()
    }

    @inlinable
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

struct PageNodeStat {
    let elementCount: Int
    let maximumCount: Int
    let elementType: Any.Type
}

// 16 KB
fileprivate let capacity = 1024 * 16 

struct PageNode<T> : ~Copyable {
    let allocator = ArenaAllocator(capacity: capacity, alignment: MemoryLayout<T>.alignment)
    let alignment = MemoryLayout<T>.alignment
    let size = MemoryLayout<T>.size
    let stride = MemoryLayout<T>.stride
    let maximumCount = capacity / MemoryLayout<T>.stride

    private var count = 0
    
    mutating func add(_ new: T) {
        guard let ptr = allocator.alloc(size: self.size, alignment: self.alignment)?.bindMemory(to: T.self, capacity: 1) else {
            // 測試所以粗暴一點
            fatalError()
        }

        count += 1
        ptr.initialize(to: new)
    }

    var stat: PageNodeStat {
        PageNodeStat(
            elementCount: count, 
            maximumCount: maximumCount,
            elementType: T.self,
        )
    }

    var hasCapcity: Bool {
        count < maximumCount
    }
}

class PageNodeHandle<T> {
    fileprivate var node = PageNode<T>()

    var access: PageNode<T> {
        _read {
            yield node
        }
    }
}

struct HandleBox<T> {
    private let _handle: PageNodeHandle<T>
    
    @inlinable
    var handle: PageNodeHandle<T> {
        _read {
            yield _handle
        }
    }

    init(_ h: PageNodeHandle<T>) {
        self._handle = h
    }

    @inlinable
    func withNode(_ fn: (inout PageNode<T>) -> ()) {
        fn(&_handle.node)
    }

}