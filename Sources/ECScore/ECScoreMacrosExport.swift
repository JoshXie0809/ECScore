@attached(member, names: named(hello), named(helloCount))
public macro AddHello() = #externalMacro(module: "ECScoreMacros", type: "AddHelloMacro")


@attached(extension, conformances: Component, names: named(createPFStorage))
@attached(peer, names: prefixed(__SparseSet_L2_))
public macro Component() = #externalMacro(module: "ECScoreMacros", type: "ComponentMacro")