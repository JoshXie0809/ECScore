final class CommandBuffer<each T: Component> {
    private let commands: (repeat HandleBox<each T>)

    @inlinable
    init(_ type: repeat (each T).Type) {
        self.commands = ( repeat Self.boxInit( each type ) )
    }

    @inline(__always)
    private static func boxInit<C: Component>(_ type: C.Type) -> HandleBox<C> {
        HandleBox(PageNodeHandle<C>())
    }

    @inlinable
    func get<C: Component>(_ type: C.Type) -> HandleBox<C>?
    {
        var result: HandleBox<C>? = nil
        repeat Self.getCommands(result: &result, commands: each commands)
        return result
    }

    @inline(__always)
    private static func getCommands<C1, C2>(result: inout HandleBox<C1>?, commands: HandleBox<C2>)
    {
        if C1.self == C2.self {
            result = commands as? HandleBox<C1>
        }
    }
}