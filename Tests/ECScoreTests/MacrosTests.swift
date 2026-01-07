import Testing
@testable import ECScore

@Component
struct Position {
    let x: Float
    let y: Float
}



@Test func testComponentMacro() async throws {
    let storage = __SparseSet_L2_Position()
    print(storage)
}
