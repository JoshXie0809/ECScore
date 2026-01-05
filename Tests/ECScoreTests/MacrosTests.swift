import Testing
@testable import ECScore

@AddHello
struct Comp3 {}

@Test func testMacros() async throws {
    let comp = Comp3()
    comp.hello()
}