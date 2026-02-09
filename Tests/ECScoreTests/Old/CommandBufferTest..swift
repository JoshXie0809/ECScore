// import Testing
// @testable import ECScore


// enum Sex {
//     case Male
//     case Female
// }

// struct User {
//     let age: Int
//     let id: Int32
//     let sex: Sex
// }

// @Test func memAllocTest() async throws {
//     let node = PageNode<User>()
//     _ = node
// }

// @Test func memCommands() async throws {
//     let commands = Commands<User>()
//     print(commands.stat)

//     for _ in 0..<2077 {
//         commands.add(User(age: 23, id: 44, sex: .Male))
//     }

//     print(commands.stat)

//     commands.reset()
//     print(commands.stat)

//     for _ in 0..<234 {
//         commands.add(User(age: 232, id: 4, sex: .Female))
//     }
//     print(commands.stat)
// }



// @Test("packs Component Type")
// func name() async throws {
//     // let buffer = CommandBuffer(Position.self, MockComponentA.self)
//     // let mockA = buffer.get(MockComponentA.self)!
//     // print(mockA.handle.access.stat)

//     // let mockB = buffer.get(MockComponentB.self)
//     // #expect(mockB == nil)

//     // let pos = buffer.get(Position.self)!
//     // print(pos.handle.access.stat)

// }