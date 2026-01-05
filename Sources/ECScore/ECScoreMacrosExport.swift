@attached(member, names: named(hello))
public macro AddHello() = #externalMacro(module: "ECScoreMacros", type: "AddHelloMacro")
