import Testing
@testable import ECScore

@AddHello
struct Comp3 {}

@Test func testMacros() async throws {
    var comp = Comp3()
    for _ in 0..<30 {
        comp.hello()
    }
    #expect(comp.helloCount == 30)
}