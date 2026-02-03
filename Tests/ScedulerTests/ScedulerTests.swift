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
    scheduler2(base, [1, 2, 10], [3, 7, 11], [4, 5], [9, 12], [4, 5, 6])
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
