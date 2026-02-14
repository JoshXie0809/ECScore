public extension TypeToken {
    @inlinable
    @inline(__always)
    func getCommandBuffer(
        base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    ) -> CommandBuffer<T>
    {
        CommandBuffer(box: getStorage(base: base))
    }
}

public struct CommandBuffer<T: Component> {
    @inline(__always)
    private let box: PFStorageBox<T>

    @inline(__always)
    @usableFromInline
    init(box: PFStorageBox<T>) { self.box = box }
}
