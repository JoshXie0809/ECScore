public extension TypeToken {
    @inlinable
    @inline(__always)
    func getStorage(
        base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    ) -> PFStorageBox<T>
    {
        base.value.storages[rid.id] as! PFStorageBox<T>
    }
}

@inlinable
@inline(__always)
public func emplace<each T>(
    _ base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    tokens: borrowing (repeat TypeToken<each T>),
    _ fn: (borrowing EmplaceEntities, borrowing EmplacePack<repeat each T> ) -> Void) 
{
    let pack = EmplacePack((repeat EmplaceStorage((each tokens).getStorage(base: base))))
    fn( EmplaceEntities(base.entities), pack )
}

public struct EmplaceEntityId {
    @usableFromInline
    internal let entity: EntityId
    
    @inlinable
    @inline(__always)
    internal init(_ eid: EntityId) { self.entity = eid }

    
    
}

public struct EmplaceEntities: ~Copyable {
    @inline(__always)
    @usableFromInline
    internal let entities: any Platform_Entity

    @inline(__always)
    @usableFromInline
    init(_ entities: any Platform_Entity) { self.entities = entities}

    @inlinable
    @inline(__always)
    public func createEntity() -> EmplaceEntityId {
        EmplaceEntityId(entities.spawn(1)[0])
    }

    @inlinable
    @inline(__always)
    public func destroyEntity(_ eeid: EmplaceEntityId) {
        entities.despawn(eeid.entity)
    }
}

public struct EmplaceStorage<T: Component> {
    @usableFromInline
    @inline(__always)
    internal var storage: PFStorageBox<T>

    @usableFromInline
    @inline(__always)
    init(_ st: PFStorageBox<T>) { self.storage = st}
    
    @inlinable
    @inline(__always)
    public mutating func addComponent(_ eeid: EmplaceEntityId, _ comp: T) {
        storage.add(eid: eeid.entity, component: comp)
    }

    @inlinable
    @inline(__always)
    public mutating func removeComponent(_ eeid: EmplaceEntityId) {
        storage.remove(eid: eeid.entity)
    }
}

public struct EmplacePack<each T: Component>: ~Copyable {
    // 將所有 Storage 放在一個元組裡
    public let storages: (repeat EmplaceStorage<each T>)
    @usableFromInline
    init(_ sts: (repeat EmplaceStorage<each T>)) { self.storages = sts }
}
