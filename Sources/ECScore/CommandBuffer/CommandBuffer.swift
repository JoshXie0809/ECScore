final class CommandBuffer<each T: Component> {
    // private let commands: (repeat HandleBox<each T>)

    // @inlinable
    // init(_ type: repeat (each T).Type) {
    //     var manifest: ComponentManifest = []
    //     repeat manifest.append(each type)
    //     var manifest_val = Raw(value: manifest).upgrade(Manifest_Facts.self)
    //     validate(validated: &manifest_val, Manifest_Facts.FlagCase.unique.rawValue)
        
    //     guard case .success = manifest_val.certify(Proof_Unique.self) else {
    //         fatalError("duplicate of type while using CommandBuffer<each T>")
    //     }

    //     self.commands = ( repeat Self.boxInit( each type ) )
    // }

    // @inline(__always)
    // private static func boxInit<C: Component>(_ type: C.Type) -> HandleBox<C> {
    //     HandleBox(PageNodeHandle<C>())
    // }

    // @inlinable
    // func get<C: Component>(_ type: C.Type) -> HandleBox<C>?
    // {
    //     var result: HandleBox<C>? = nil
    //     repeat Self.getCommands(result: &result, commands: each commands)
    //     return result
    // }

    // @inline(__always)
    // private static func getCommands<C1, C2>(result: inout HandleBox<C1>?, commands: HandleBox<C2>)
    // {
    //     if C1.self == C2.self {
    //         result = commands as? HandleBox<C1>
    //     }
    // }
}