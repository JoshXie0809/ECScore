@attached(member, names: named(hello), named(helloCount))
public macro AddHello() = #externalMacro(module: "ECScoreMacros", type: "AddHelloMacro")
