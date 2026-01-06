import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main 
struct ECScoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AddHelloMacro.self,
        ComponentMacro.self,
    ]
}