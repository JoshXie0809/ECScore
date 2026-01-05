import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// 用法：
/// @AddHello
/// struct A {}
public struct AddHelloMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf decl: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 這裡回傳「要插入到 type member 裡」的宣告（例如 func/var）
        return [
            """
            func hello() {
                print("hello from macro")
            }
            """
        ]
    }
}