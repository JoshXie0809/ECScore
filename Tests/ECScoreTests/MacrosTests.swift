import Testing
@testable import ECScore

@FastProxy
struct Position: Component {
    var x: Float = 0.0
    var y: Float = 0.0
}

@Test func createFastProxy() async throws {
    let person_ptr = UnsafeMutablePointer<Position>.allocate(capacity: 1)
    defer { person_ptr.deallocate() }
    person_ptr.pointee.x = Float(1234.5)
    person_ptr.pointee.y = Float(5432.1)

    let person_proxy = Position.ProxyMembers(ptr: person_ptr)

    _ = person_proxy
}