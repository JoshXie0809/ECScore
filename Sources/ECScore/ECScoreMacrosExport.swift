// @attached(member, names: named(hello), named(helloCount))
// public macro AddHello() = #externalMacro(module: "ECScoreMacros", type: "AddHelloMacro")


@attached(extension, conformances: Component, names: named(createPFStorage))
public macro Component() = #externalMacro(module: "ECScoreMacros", type: "ComponentMacro")

@freestanding(expression)
public macro hs_fnv1a64(_ string: String) -> UInt64 = #externalMacro(module: "ECScoreMacros", type: "HashedString_FNV1A64_Macro")


@attached(member, names: named(ProxyMembers))
@attached(extension, conformances: FastComponentProtocol, names: named(FastProxyType))
public macro FastProxy() = #externalMacro(module: "ECScoreMacros", type: "FastProxyMacro")