@attached(member, names: named(hello), named(helloCount))
public macro AddHello() = #externalMacro(module: "ECScoreMacros", type: "AddHelloMacro")


@attached(extension, conformances: Component, names: named(createPFStorage))
@attached(peer, names: prefixed(__SparseSet_L2_))
public macro Component() = #externalMacro(module: "ECScoreMacros", type: "ComponentMacro")

@freestanding(expression)
public macro hs_fnv1a64(_ string: String) -> UInt64 = #externalMacro(module: "ECScoreMacros", type: "HashedString_FNV1A64_Macro")