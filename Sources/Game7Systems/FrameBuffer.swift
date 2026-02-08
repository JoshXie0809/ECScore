class FrameBuffer {
    public let width: Int
    public let height: Int
    private var buffer: ContiguousArray<UInt8>

    init(width: UInt32, height: UInt32) {
        self.width = Int(width)
        self.height = Int(height)
        self.buffer = ContiguousArray(repeating: UInt8(ascii: " "), count: Int(width) * Int(height))
    }

    func clear() {
        for i in 0..<buffer.count {
            buffer[i] = UInt8(ascii: " ") 
        }
    }

    @inline(__always)
    func draw(x: Int, y: Int, char: UInt8) {
        if y >= 0 && y < height && x >= 0 && x < width {
            buffer[x + y * width] = char
        }
    }

    @inline(__always)
    func getBufferPtr() -> UnsafeMutablePointer<UInt8> {
        self.buffer.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }

    func renderToStringCount() -> Int {
        let space = UInt8(ascii: " ")
        var result = 0
        for ch in buffer {
            if ch != space { result += 1 }
        }
        return result
    }

}

