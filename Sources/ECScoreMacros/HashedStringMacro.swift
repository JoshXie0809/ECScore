import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct HashedString_FNV1A64_Macro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // 1. 抓取 Macro 的參數 (例如 #id("sss"))
        guard let argument = node.arguments.first?.expression,
              let stringLiteral = argument.as(StringLiteralExprSyntax.self),
              let segments = stringLiteral.segments.first,
              case .stringSegment(let segment) = segments else {
            throw MacroExpansionErrorMessage("needs string is literally written on code (String Literal)")
        }

        let inputString = segment.content.text
        
        // 2. 執行編譯期 FNV-1a 計算
        let hashValue = calculateFNV1a(inputString)
        
        // 3. 回傳一個 UInt64 的數字字面量給編譯器
        return "\(raw: hashValue)"
    }

    private static func calculateFNV1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

// 錯誤處理的小工具
struct MacroExpansionErrorMessage: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}