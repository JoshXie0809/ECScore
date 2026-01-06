import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// 用法：
/// @Component
/// struct Comp {}
/// 
/// // generate
/// extension Comp: Component {}
/// 
/// // peer struct
/// 

public struct ComponentMacro: ExtensionMacro, PeerMacro {

    public static func expansion(
        of node: AttributeSyntax, 
        attachedTo decl: some DeclGroupSyntax, 
        providingExtensionsOf type: 
        some TypeSyntaxProtocol, 
        conformingTo protocols: [TypeSyntax], 
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] 
    {
        guard let structDecl = decl.as(StructDeclSyntax.self) else {
            throw ECScoreError.compOnlyOnStrucDecl
        }
        _ = structDecl

        return [
            try ExtensionDeclSyntax("""
            extension \(type): Component {}
            """)
        ]
    
    }

    public static func expansion(
        of node: AttributeSyntax, 
        providingPeersOf decl: some DeclSyntaxProtocol, 
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = decl.as(StructDeclSyntax.self) else {
            throw ECScoreError.compOnlyOnStrucDecl
        }

        let typeName = structDecl.trimmed.name.text
        let storageName = "__SparseSet_L2_\(typeName)"

        let storageDecl: DeclSyntax = """
            public struct \(raw: storageName): SparseSet {
                private var _storage: SparseSet_L2<\(raw: typeName)>

                init() {
                    self._storage = SparseSet_L2<\(raw: typeName)>()
                }

                @inline(__always)
                public mutating func remove(_ eid: EntityId) {
                    _storage.remove(eid)
                }
            }
            """

        return [storageDecl]

    }

}


enum ECScoreError: CustomStringConvertible, Error {
    case compOnlyOnStrucDecl
    case tooManyDeclsInOneLine
    case DoubleDeclOfComponetId

    var description: String {
        switch self {
        case .compOnlyOnStrucDecl: return "@Component Only can apply on struct."
        case .tooManyDeclsInOneLine: return "in @Component struct, one line one decl" 
        case .DoubleDeclOfComponetId: return "double decl of componentId"
        }
    }
}





















    // public static func expansion(
    //     of node: AttributeSyntax,
    //     providingMembersOf decl: some DeclGroupSyntax,
    //     in context: some MacroExpansionContext
    // ) throws -> [DeclSyntax]
    // {
    //     guard let strDecl = decl.as(StructDeclSyntax.self) else {
    //         throw ECScoreError.compOnlyOnStrucDecl 
    //     }
    //     let members = strDecl.memberBlock.members
    //     let variableNames = try members.compactMap { member -> String? in
    //         guard let variable = member.decl.as(VariableDeclSyntax.self) else {
    //             return nil
    //         }
    //         let bindings = variable.bindings
    //         guard bindings.count == 1 else {
    //             throw ECScoreError.tooManyDeclsInOneLine
    //         }
    //         return bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text 
    //     }
    //     for variableName in variableNames {
    //         guard variableName != "componentId" else {
    //             throw ECScoreError.DoubleDeclOfComponetId
    //         }
    //     }
    //     return [
    //         // need to initialize at world registery
    //         "private(set) static var componentId: Int = -1"
    //     ]
    // }