import Testing
import Foundation
@testable import ECScore

@Suite("Scheduler testing")
struct name {
    @Test("create Mask Test")
    func createMaskTest() async throws {
        let maxRidId1 = 0
        #expect(MASK.createMask(maxRidId1).count == 1)

        let maxRidId2 = -1
        #expect(MASK.createMask(maxRidId2).count == 0)

        let maxRidId3 = 63
        #expect(MASK.createMask(maxRidId3).count == 1)

        let maxRidId4 = 64
        #expect(MASK.createMask(maxRidId4).count == 2)
    }

    @Test("Mask can contain rid")
    func MaskCanWearRIDS_TEST() async throws {
        var m1 = MASK.createMask(109) // maxRid = 109
        let rids1 = [0, 2, 3]
        let ok1 = m1.mask_CAN_WEAR_RIDS(rids1)
        #expect(ok1 == true)
        #expect((m1[0] & 0b1101) == 0b1101)

        let rids2 = [1, 5, 9]
        let ok2 = m1.mask_CAN_WEAR_RIDS(rids2)
        #expect(ok2 == true)

        let rids3 = [2, 4] // 2 is added
        let ok3 = m1.mask_CAN_WEAR_RIDS(rids3)
        #expect(ok3 == false)
    }

}


@Test func schedulerTest() async throws {
    let base = makeBootedPlatform()
    var rng = Xoshiro128(seed: 12345)
    let clock = ContinuousClock()

    for iter in 0..<20 {
        var RIDSs = [[Int]]()
        for _ in 0..<2000 {
            var rids = [Int]()
            for rid in 0...109 { // maxRid = 109
                if rng.next() % 1000 < 40 {
                    rids.append(rid)
                }
            }

            if rids.count > 0 { RIDSs.append(rids) }
        }

        let ts0 = clock.now
        scheduler2(base, RIDSs)
        print("iter: \(iter)")
        print("total schedule time: ", clock.now - ts0)
        print()
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

    @inline(__always)
    private static func rotl(_ x: UInt32, _ k: Int) -> UInt32 {
        return (x << k) | (x >> (32 - k))
    }

    public mutating func next() -> UInt32 {
        let result = Xoshiro128.rotl(state.1 &* 5, 7) &* 9

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









func makeBootedPlatform() -> Validated<BasePlatform, Proof_Handshake, Platform_Facts> {
    let base = BasePlatform()
    let registry = RegistryPlatform()
    let entities = EntityPlatForm_Ver0()
    
    // 建立初始環境：Registry(0), Entities(1)
    base.boot(registry: registry, entities: entities)

    var pf_val = Raw(value: base).upgrade(Platform_Facts.self)
    validate(validated: &pf_val, .handshake)

    // 被驗證可以 handshake 的平台
    guard case let .success(pf_handshake) = pf_val.certify(Proof_Handshake.self) else {
        fatalError()
    }

    return pf_handshake
}
