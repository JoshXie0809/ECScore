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
    @usableFromInline
    @inline(__always)
    internal var box: PFStorageBox<T>

    @inline(__always)
    @usableFromInline
    init(box: PFStorageBox<T>) { self.box = box }

    @inlinable
    @inline(__always)
    public mutating func addCommand(_ itid: borrowing IterId, _ comp: consuming T = T()) {
        // version is no meaning in view api
        box.add(eid: EntityId(id: itid.eidId, version: -1), component: comp)
    }

    @inlinable
    @inline(__always)
    public mutating func removeAll() {
        box.removeAll()
    }

}
