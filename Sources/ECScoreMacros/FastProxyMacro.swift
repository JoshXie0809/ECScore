import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FastProxyMacro: MemberMacro, ExtensionMacro {
    
    // -------------------------------------------------------------------------
    // 1. MemberMacro: 生成 ProxyMembers (這部分保持原本正確的邏輯)
    // -------------------------------------------------------------------------
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf decl: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = decl.as(StructDeclSyntax.self) else { return [] }
        let typeName = structDecl.name.text
        let isPublic = structDecl.modifiers.contains { $0.name.text == "public" }
        let access = isPublic ? "public " : ""
        
        // 這裡呼叫你原本寫好的 generateProxyMembersProperties
        let propertiesCode = generateProxyMembersProperties(from: structDecl, access: access)

        return ["""
        \(raw: access)struct ProxyMembers: ECScore.FastProxyPointer {
            \(raw: access)typealias T = \(raw: typeName)
            @inline(__always) private let ptr: UnsafeMutablePointer<\(raw: typeName)>
            @inline(__always) \(raw: access)init(ptr: UnsafeMutablePointer<\(raw: typeName)>) { self.ptr = ptr }
            \(raw: propertiesCode)
        }
        """]
    }

    // -------------------------------------------------------------------------
    // 2. ExtensionMacro: 只做一件事 -> 讓 Component 遵循協議
    // -------------------------------------------------------------------------
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo decl: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = decl.as(StructDeclSyntax.self) else { return [] }
        let typeName = structDecl.name.text
        
        return [
            try ExtensionDeclSyntax("""
            extension \(raw: typeName): ECScore.FastComponentProtocol {}
            """)
        ]
    }

    // (保留原本的 generateProxyMembersProperties 輔助函數，代碼略)
    private static func generateProxyMembersProperties(from structDecl: StructDeclSyntax, access: String) -> String {
        // ... 保持你原本的實作 ...
        let variableDecls = structDecl.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { !($0.modifiers.contains { $0.name.text == "static" }) }

        var code = ""
        for varDecl in variableDecls {
            let isLet = varDecl.bindingSpecifier.text == "let"
            for binding in varDecl.bindings {
                if let name = binding.pattern.as(IdentifierPatternSyntax.self),
                   let type = binding.typeAnnotation?.type.trimmedDescription {
                    let prop = name.identifier.text
                    code += """
                    @inline(__always)
                    \(access)var \(prop): \(type) {
                        @inline(__always) _read { yield ptr.pointee.\(prop) }
                    """
                    if !isLet {
                        code += "@inline(__always) nonmutating _modify { yield &ptr.pointee.\(prop) }"
                    }
                    code += "}\n"
                }
            }
        }
        return code
    }
}