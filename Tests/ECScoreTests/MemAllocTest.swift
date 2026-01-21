import Testing
@testable import ECScore

enum Sex {
    case Male
    case Female
}

struct User {
    let age: Int
    let sex: Sex
}

@Test func memAllocTest() async throws {
    let node = PageNode<User>()

    let ptr = node.add(User(age: 22, sex: .Female))
    print(ptr.pointee)
}