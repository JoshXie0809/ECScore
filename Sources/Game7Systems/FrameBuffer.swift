class FrameBuffer {
    public let width: Int
    public let height: Int
    private var buffer: ContiguousArray<UInt8>

    init(width: UInt32, height: UInt32) {
        self.width = Int(width)
        self.height = Int(height)
        // 使用空白字元的 ASCII 編碼 (32) 初始化
        self.buffer = ContiguousArray(repeating: UInt8(ascii: " "), count: Int(width) * Int(height))
    }

    func clear() {
        // 重置為空白字元 (ASCII 32)
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
    func reserveCapacity(_ n: Int) {
        buffer.reserveCapacity(n)
    }

    @inline(__always)
    func getBufferPtr() -> UnsafeMutablePointer<UInt8> {
        self.buffer.withUnsafeMutableBufferPointer { $0.baseAddress! }
    }

    func renderToString() -> String {
        var result = ""
        for y in 0..<height {
            let start = y * width
            let end = start + width
            let line = buffer[start..<end]
            
            // 此時 buffer 是 [UInt8]，這行就不會報錯了
            if let row = String(bytes: line, encoding: .ascii) {
                result += row + "\n"
            }
        }
        return result
    }
}

