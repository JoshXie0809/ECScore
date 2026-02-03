import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FastProxyMacro: MemberMacro, ExtensionMacro {
    // -------------------------------------------------------------------------
    // 1. MemberMacro: 在內部生成 ProxyMembers 結構
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
        
        // 提取成員：跳過 static (因為指標存取不到)
        let variableDecls = structDecl.memberBlock.members.compactMap { member -> VariableDeclSyntax? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            if varDecl.modifiers.contains(where: { $0.name.text == "static" }) { return nil }
            return varDecl
        }
        
        var propertiesCode = ""
        for varDecl in variableDecls {
            let isLet = varDecl.bindingSpecifier.text == "let"
            for binding in varDecl.bindings {
                if let name = binding.pattern.as(IdentifierPatternSyntax.self),
                   let typeAnnotation = binding.typeAnnotation ?? varDecl.bindings.last?.typeAnnotation {
                    
                    let prop = name.identifier.text
                    let type = typeAnnotation.type.trimmedDescription
                    
                    propertiesCode += """
                    @inline(__always)
                    \(access)var \(prop): \(type) {
                        @inline(__always) _read { yield ptr.pointee.\(prop) }
                    """
                    if !isLet {
                        propertiesCode += "@inline(__always) _modify { yield &ptr.pointee.\(prop) }"
                    }
                    propertiesCode += "}\n"
                }
            }
        }

        return ["""
        \(raw: access)struct ProxyMembers: ECScore.FastProxyPointer {
            \(raw: access)typealias T = \(raw: typeName)
            private let ptr: UnsafeMutablePointer<\(raw: typeName)>
            @inline(__always) \(raw: access)init(ptr: UnsafeMutablePointer<\(raw: typeName)>) { self.ptr = ptr }
            \(raw: propertiesCode)
        }
        """]
    }

    // -------------------------------------------------------------------------
    // 2. ExtensionMacro: 修正後的簽名，僅連結協議
    // -------------------------------------------------------------------------
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo decl: some DeclGroupSyntax, // 注意這裡必須是 DeclGroupSyntax
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // 這裡只負責連結 FastComponentProtocol，完全不碰你的 createPFStorage
        return [
            try ExtensionDeclSyntax("""
            extension \(type): ECScore.FastComponentProtocol {
                public typealias FastProxyType = \(type).ProxyMembers
            }
            """)
        ]
    }
}