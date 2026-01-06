@attached(member, names: named(hello), named(helloCount))
public macro AddHello() = #externalMacro(module: "ECScoreMacros", type: "AddHelloMacro")


@attached(extension, conformances: Component)
public macro Component() = #externalMacro(module: "ECScoreMacros", type: "ComponentMacro")