import MetalKit

final class GameMTKView: MTKView {
    // 必須允許成為焦點，才能接收鍵盤事件
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        InputManager.shared.handleKeyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        InputManager.shared.handleKeyUp(event)
    }
}
