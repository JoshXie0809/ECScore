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

struct PagesStat {
    let elementCount: Int
    let maximumCount: Int
    let elementType: Any.Type
    let totalPages: Int
}

// 16 KB
fileprivate let capacity = 1024 * 16 

struct PageNode<T> : ~Copyable {
    private let allocator = ArenaAllocator(capacity: capacity, alignment: MemoryLayout<T>.alignment)
    
    mutating func add(_ new: T, _ header: borrowing PageHeader<T>) {
        guard let ptr = allocator
            .alloc(size: header.size, alignment: header.alignment)?
            .bindMemory(to: T.self, capacity: 1) 
        
        else {
            // 測試所以粗暴一點
            fatalError("arena mem is out of memory")
        }

        ptr.initialize(to: new)
    }

    mutating func reset() {
        allocator.reset()
    }
}

struct PageHeader<T>: ~Copyable {
    let alignment = MemoryLayout<T>.alignment
    let size = MemoryLayout<T>.size
    let stride = MemoryLayout<T>.stride
    let maximumCount = capacity / MemoryLayout<T>.stride
}

final class Commands<T> {
    let header = PageHeader<T>()
    var pages: [PageNodeHandle<T>] = []
    private var count = 0

    init() {
        assert(header.maximumCount > 0)
    }

    @inline(__always)
    var currentPageIndex: Int {
        count / header.maximumCount
    }

    @inline(__always)
    private static func ensureCapacity(commands: Commands<T>) {
        if !commands.hasCapcity {
            commands.pages.append(PageNodeHandle<T>())
        }
    }

    @inlinable
    func add(_ new: T) {
        Self.ensureCapacity(commands: self)
        let currentPage = pages[currentPageIndex]
        currentPage.mut.add(new, self.header)
        count += 1
    }

    @inlinable
    func reset() {
        count = 0
        for page in pages {
            page.mut.reset()
        }
    }

    var stat: PagesStat {
        PagesStat(
            elementCount: count, 
            maximumCount: (header.maximumCount * pages.count),
            elementType: T.self,
            totalPages: pages.count
        )
    }

    var hasCapcity: Bool {
        count < (header.maximumCount * pages.count)
    }

}

class PageNodeHandle<T> {
    fileprivate var node = PageNode<T>()
    var view: PageNode<T> {
        _read {
            yield node
        }
    }

    var mut: PageNode<T> {
        _read {
            yield node
        }

        _modify {
            yield &node
        }
    }
}

// struct HandleBox<T> {
//     private let _handle: PageNodeHandle<T>
//     @inlinable
//     var handle: PageNodeHandle<T> {
//         _read {
//             yield _handle
//         }
//     }
//     init(_ h: PageNodeHandle<T>) {
//         self._handle = h
//     }
//     @inlinable
//     func withNode(_ fn: (inout PageNode<T>) -> ()) {
//         fn(&_handle.node)
//     }
// }