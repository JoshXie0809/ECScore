import AppKit
import simd

@MainActor
final class InputManager {
    static let shared = InputManager()

    private var pressedKeys = Set<UInt16>()

    enum Key: UInt16 {
        case w = 13, a = 0, s = 1, d = 2
        case up = 126, left = 123, down = 125, right = 124
    }

    @inlinable
    func handleKeyDown(_ event: NSEvent) {
        pressedKeys.insert(event.keyCode)
    }

    @inlinable
    func handleKeyUp(_ event: NSEvent) {
        pressedKeys.remove(event.keyCode)
    }

    @inlinable
    func isPressed(_ key: Key) -> Bool {
        return pressedKeys.contains(key.rawValue)
    }

    var moveVector: simd_float2 {
        var dir = simd_float2(0, 0)
        
        if isPressed(.w) || isPressed(.up) { dir.y += 1 }
        if isPressed(.s) || isPressed(.down) { dir.y -= 1 }
        if isPressed(.a) || isPressed(.left) { dir.x -= 1 }
        if isPressed(.d) || isPressed(.right) { dir.x += 1 }
        
        // 單位化向量，防止斜向移動過快
        return length(dir) > 0 ? normalize(dir) : dir
    }
}