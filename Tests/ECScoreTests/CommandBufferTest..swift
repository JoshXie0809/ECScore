import Testing
@testable import ECScore

@Test("packs Component Type")
func name() async throws {
    let buffer = CommandBuffer(Position.self, MockComponentA.self)
    let mockA = buffer.get(MockComponentA.self)!
    print(mockA.handle.access.stat)

    let mockB = buffer.get(MockComponentB.self)
    #expect(mockB == nil)

    let pos = buffer.get(Position.self)!
    print(pos.handle.access.stat)

}