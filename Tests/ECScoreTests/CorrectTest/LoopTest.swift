import Testing
import Foundation
@testable import ECScore


@Test func interstionTest() async throws {

    var rng = Xoshiro128(seed: UInt32(11111))

    for _ in 1...10 {
        let base = makeBootedPlatform()
        let ttokens = interop(base, 
            MockComponentA.self, 
            MockComponentB.self,
            MockComponentC.self,
            MockComponentD.self,
            MockComponentE.self,
        )

        var count = 0
        var validated_count = 0

        emplace(base, tokens: ttokens) {
            entities, pack in
            var (a, b, c, d, e) = pack.storages

            for _ in 1...10_000 {
                let entity = entities.createEntity()

                let roll1 = rng.next() & 1
                let roll2 = rng.next() & 1
                let roll3 = rng.next() & 1
                let roll4 = rng.next() & 1
                let roll5 = rng.next() & 1
                
                if roll1 == 0 { a.addComponent(entity, MockComponentA()) }
                if roll2 == 0 { b.addComponent(entity, MockComponentB()) }
                if roll3 == 0 { c.addComponent(entity, MockComponentC()) }
                if roll4 != 0 { d.addComponent(entity, MockComponentD()) }
                if roll5 != 0 { e.addComponent(entity, MockComponentE()) }

                if roll1 == 0 && roll2 == 0 && roll3 == 0 && roll4 == 0 && roll5 == 0 {
                    count += 1
                }

            }
        }

        let withTagTokens = interop(base, MockComponentA.self, MockComponentB.self, MockComponentC.self,)
        let withoutTagTokens = interop(base, MockComponentD.self, MockComponentE.self)
        
        view(base: base, with: (), withTag: withTagTokens, withoutTag: withoutTagTokens) {
            _ in

            validated_count += 1
        }

        #expect(count == validated_count)

    }
}





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

    public mutating func range(_ l: UInt32, _ h: UInt32) -> UInt32 {
        let range = h - l + 1
        return self.next() % range + l
    }
}