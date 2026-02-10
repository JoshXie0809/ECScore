import Testing
@testable import ECScore

struct MockComponentA1: Component {}
struct MockComponentA2: Component {}
struct MockComponentA3: Component {}
struct MockComponentA4: Component {}
struct MockComponentA5: Component {}


@Test func intersectionTest() async throws {
    // let ITER = 100
    let ITER = 10
    var rng = Xoshiro128(seed: UInt32(666))

    for _ in 1...ITER {
        let base = makeBootedPlatform()
        let ttokens = interop(base, 
            MockComponentA.self, 
            MockComponentB.self,
            MockComponentC.self,
            MockComponentD.self,
            MockComponentE.self,
            MockComponentA1.self, 
            MockComponentA2.self, 
            MockComponentA3.self, 
            MockComponentA4.self, 
            MockComponentA5.self, 
        )

        var count = 0
        var validated_count = 0

        emplace(base, tokens: ttokens) {
            entities, pack in
            var (a, b, c, d, e, a1, a2, a3, a4, a5) = pack.storages
            var entitiesToDestroy = [EmplaceEntityId]()
            entitiesToDestroy.reserveCapacity(50_000)

            for _ in 1...50_000 {
                let entity = entities.createEntity()

                let roll1 = rng.next() & 1
                let roll2 = rng.next() & 1
                let roll3 = rng.next() & 1
                let roll4 = rng.next() & 1
                let roll5 = rng.next() & 1
                let rolla1 = rng.next() & 1
                let rolla2 = rng.next() & 1
                let rolla3 = rng.next() & 1
                let rolla4 = rng.next() & 1
                let rolla5 = rng.next() & 1
                
                let destroy_roll = rng.next() & 1
                
                if roll1 == 0 { a.addComponent(entity, MockComponentA()) }
                if roll2 == 0 { b.addComponent(entity, MockComponentB()) }
                if roll3 == 0 { c.addComponent(entity, MockComponentC()) }
                if roll4 != 0 { d.addComponent(entity, MockComponentD()) }
                if roll5 != 0 { e.addComponent(entity, MockComponentE()) }

                if rolla1 == 0 { a1.addComponent(entity, MockComponentA1()) }
                if rolla2 == 0 { a2.addComponent(entity, MockComponentA2()) }
                if rolla3 != 0 { a3.addComponent(entity, MockComponentA3()) }
                if rolla4 != 0 { a4.addComponent(entity, MockComponentA4()) }
                if rolla5 != 0 { a5.addComponent(entity, MockComponentA5()) }

                var isTrue = false
                if 
                roll1 == 0 && roll2 == 0 && roll3 == 0 && roll4 == 0 && roll5 == 0 &&
                rolla1 == 0 && rolla2 == 0 && rolla3 == 0 && rolla4 == 0 && rolla5 == 0 {
                    isTrue = true
                    count += 1
                }

                if destroy_roll == 0 {
                    entitiesToDestroy.append(entity)
                    if isTrue { count -= 1 }
                }
            }

            for entity in entitiesToDestroy {
                a.removeComponent(entity)
                b.removeComponent(entity)
                c.removeComponent(entity)
                d.removeComponent(entity)
                e.removeComponent(entity)

                a1.removeComponent(entity)
                a2.removeComponent(entity)
                a3.removeComponent(entity)
                a4.removeComponent(entity)
                a5.removeComponent(entity)

                entities.destroyEntity(entity)
            }

        }

        let withTagTokens = interop(base, MockComponentA.self, MockComponentB.self, MockComponentC.self, MockComponentA1.self, MockComponentA2.self)
        let withoutTagTokens = interop(base, MockComponentD.self, MockComponentE.self, MockComponentA3.self, MockComponentA4.self, MockComponentA5.self)
        
        view(base: base, with: (), withTag: withTagTokens, withoutTag: withoutTagTokens) {
            _ in

            validated_count += 1
        }
        // print(count)
        #expect(count == validated_count)

    }
}

//  swift test -c release --sanitize=address --filter intersectionTest

struct FooLogic: SystemBody {
    let validated_count: UnsafeMutablePointer<Int>

    typealias Components = ()
    func execute(taskId: Int, components: borrowing ()) {
        validated_count.pointee += 1
    }

}

@Test func intersectionTest2() async throws {
    // let ITER = 100
    let ITER = 10
    var rng = Xoshiro128(seed: UInt32(666666))

    for _ in 1...ITER {
        let base = makeBootedPlatform()
        let ttokens = interop(base, 
            MockComponentA.self, 
            MockComponentB.self,
            MockComponentC.self,
            MockComponentD.self,
            MockComponentE.self,
            MockComponentA1.self, 
            MockComponentA2.self, 
            MockComponentA3.self, 
            MockComponentA4.self, 
            MockComponentA5.self, 
        )

        var count = 0

        emplace(base, tokens: ttokens) {
            entities, pack in
            var (a, b, c, d, e, a1, a2, a3, a4, a5) = pack.storages
            var entitiesToDestroy = [EmplaceEntityId]()
            entitiesToDestroy.reserveCapacity(50_000)

            for _ in 1...50_000 {
                let entity = entities.createEntity()

                let roll1 = rng.next() & 1
                let roll2 = rng.next() & 1
                let roll3 = rng.next() & 1
                let roll4 = rng.next() & 1
                let roll5 = rng.next() & 1
                let rolla1 = rng.next() & 1
                let rolla2 = rng.next() & 1
                let rolla3 = rng.next() & 1
                let rolla4 = rng.next() & 1
                let rolla5 = rng.next() & 1
                
                let destroy_roll = rng.next() & 1
                
                if roll1 == 0 { a.addComponent(entity, MockComponentA()) }
                if roll2 == 0 { b.addComponent(entity, MockComponentB()) }
                if roll3 == 0 { c.addComponent(entity, MockComponentC()) }
                if roll4 != 0 { d.addComponent(entity, MockComponentD()) }
                if roll5 != 0 { e.addComponent(entity, MockComponentE()) }

                if rolla1 == 0 { a1.addComponent(entity, MockComponentA1()) }
                if rolla2 == 0 { a2.addComponent(entity, MockComponentA2()) }
                if rolla3 != 0 { a3.addComponent(entity, MockComponentA3()) }
                if rolla4 != 0 { a4.addComponent(entity, MockComponentA4()) }
                if rolla5 != 0 { a5.addComponent(entity, MockComponentA5()) }

                var isTrue = false
                if 
                roll1 == 0 && roll2 == 0 && roll3 == 0 && roll4 == 0 && roll5 == 0 &&
                rolla1 == 0 && rolla2 == 0 && rolla3 == 0 && rolla4 == 0 && rolla5 == 0 {
                    isTrue = true
                    count += 1
                }

                if destroy_roll == 0 {
                    entitiesToDestroy.append(entity)
                    if isTrue { count -= 1 }
                }
            }

            for entity in entitiesToDestroy {
                a.removeComponent(entity)
                b.removeComponent(entity)
                c.removeComponent(entity)
                d.removeComponent(entity)
                e.removeComponent(entity)

                a1.removeComponent(entity)
                a2.removeComponent(entity)
                a3.removeComponent(entity)
                a4.removeComponent(entity)
                a5.removeComponent(entity)

                entities.destroyEntity(entity)
            }

        }

        let withTagTokens = interop(base, MockComponentA.self, MockComponentB.self, MockComponentC.self, MockComponentA1.self, MockComponentA2.self)
        let withoutTagTokens = interop(base, MockComponentD.self, MockComponentE.self, MockComponentA3.self, MockComponentA4.self, MockComponentA5.self)
        let vc = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer { vc.deallocate() }
        vc.pointee = 0

        let logic = FooLogic(validated_count: vc)
        view(base: base, with: (), withTag: withTagTokens, withoutTag: withoutTagTokens, logic)
        // print(count)
        #expect(count == vc.pointee)

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

@Test func singleComponentTest() async throws {
    let base = makeBootedPlatform()
    let pToken = interop(base, Position.self)
    let seed = UInt32.random(in: 0...18766)
    var rng = Xoshiro128(seed: seed)

    var count = 0
    emplace(base, tokens: pToken) {
        entities, pack in
        var pSt = pack.storages

        for _ in 0..<1_000_000 {
            let entity = entities.createEntity()
            let roll = rng.next() & (4096 * 4 - 1)
            if roll == 0 { 
                count += 1
                pSt.addComponent(entity, Position(x: 1.23, y: 3.23)) 
            }
        }
    }
    var vc = 0
    view(base: base, with: pToken) {
        _, pos in
        vc += 1
    }

    print(seed, count)
    #expect(count == vc)
}
