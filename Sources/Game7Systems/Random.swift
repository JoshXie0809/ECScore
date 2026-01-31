import Foundation

struct Xoshiro128 {
    var state: (UInt32, UInt32, UInt32, UInt32)

    init(seed: UInt32) {
        self.state = (
            seed &+ 3,
            seed &+ 5,
            seed &+ 7,
            seed &+ 11
        )
    }

    // 模仿 C++ 的 rotl (Rotate Left)
    @inline(__always)
    private static func rotl(_ x: UInt32, _ k: Int) -> UInt32 {
        return (x << k) | (x >> (32 - k))
    }

    // 模仿 C++ 的 next() 或是 operator()
    public mutating func next() -> UInt32 {
        // 1. 計算結果 (scrambler: rotl(s1 * 5, 7) * 9)
        let result = Xoshiro128.rotl(state.1 &* 5, 7) &* 9

        // 2. 更新狀態
        let t = state.1 << 9

        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3

        state.2 ^= t
        state.3 = Xoshiro128.rotl(state.3, 11)

        return result
    }
}