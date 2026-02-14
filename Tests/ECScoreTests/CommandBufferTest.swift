import Testing
@testable import ECScore

struct CommandBufferTagA: TagComponent {}

@Test func CommandBufferTest() async throws {
    let base = makeBootedPlatform()
    let token = interop(base, CommandBufferTagA.self)
    let tokenA = interop(base, MockComponentA.self)

    let cmdbf = token.getCommandBuffer(base: base)

    print(cmdbf)

}