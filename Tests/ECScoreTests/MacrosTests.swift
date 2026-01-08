import Testing
@testable import ECScore

@Component
struct Position {
    var x: Float
    var y: Float
}



@Test func testComponentMacro() async throws {
    let storage = __SparseSet_L2_Position()
    print(storage)
}
