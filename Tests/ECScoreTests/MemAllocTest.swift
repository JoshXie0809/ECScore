import Testing
@testable import ECScore

enum Sex {
    case Male
    case Female
}

struct User {
    let age: Int
    let id: Int32
    let sex: Sex
}

@Test func memAllocTest() async throws {
    let node = PageNodeHandle<User>()
    _ = node
}

@Test func handleTest() async throws {
    let box = HandleBox(PageNodeHandle<User>())

    let view2 = box.handle
        
    box.withNode { node in
        node.add(User(age: 12, id: 23, sex: .Female))
    }

    print(view2.access.stat)

}