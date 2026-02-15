public protocol Platform_Entity: Platform, Component, AnyObject {
    
    @inlinable @inline(__always)
    func spawn(_: Int) -> [EntityId]
    
    @inlinable @inline(__always)
    func despawn(_: EntityId)

    @inlinable @inline(__always)
    func despawnAndRemoveComponents(
        _: EntityId,
        _: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    )
    
    @inlinable @inline(__always)
    func forEachLiveId(_ body: (EntityId) -> Void)
    
    @inlinable @inline(__always)
    func isValid(_ eid: EntityId) -> Bool

    @inlinable @inline(__always)
    var maxId: Int { get }

    @inlinable @inline(__always)
    var _activeMaskPtr: UnsafePointer<UInt64> { get }
    
}

public final class EntityPlatForm_Ver0: Platform_Entity, Component {
    @inline(__always)
    private var entities: Entities = Entities()
    public init() {}

    @inline(__always)
    public var maxId: Int { entities.maxId }

    @inline(__always)
    public func isValid(_ eid: EntityId) -> Bool {
        return entities.isValid(eid)
    }

    @inline(__always)
    public func spawn(_ n: Int) -> [EntityId] {
        entities.spawn(n)
    }

    @inline(__always)
    public func despawn(_ eid: EntityId) {
        entities.despawn(eid)
    }

    @inline(__always)
    public func despawnAndRemoveComponents(
        _ eid: EntityId, 
        _ base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    ) {
        for i in 0..<base.value.storages.count {
            base.value.storages[i]!.remove(eid: eid)
        }

        entities.despawn(eid)
    }

    public func forEachLiveId(_ body: (EntityId) -> Void) {
        for i in 0..<entities.maxId {
            if entities.idIsActive(i) {
                body(EntityId(id: i, version: entities.getVersion(i)))
            }
        }
    }

    @inline(__always)
    public var _activeMaskPtr: UnsafePointer<UInt64> {
        return entities._isActivePtr
    }
}