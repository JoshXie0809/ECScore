public extension TypeToken {
    @inlinable
    func getStorage(
        base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    ) -> PFStorageBox<T>
    {
        base.value.storages[rid.id] as! PFStorageBox<T>
    }
}

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
    fileprivate let entity: EntityId
    fileprivate init(_ eid: EntityId) { self.entity = eid }
    @inline(__always)
    init(entity: EntityId) { self.entity = entity }
}

public struct EmplaceEntities: ~Copyable {
    @inline(__always)
    fileprivate let entities: Platform_Entity
    init(_ entities: Platform_Entity) { self.entities = entities}

    @inline(__always)
    public func createEntity() -> EmplaceEntityId {
        EmplaceEntityId(entities.spawn(1)[0])
    }

    @inline(__always)
    public func destroyEntity(_ eeid: EmplaceEntityId) {
        entities.despawn(eeid.entity)
    }
}

public struct EmplaceStorage<T: Component> {
    @inline(__always)
    fileprivate var storage: PFStorageBox<T>
    init(_ st: PFStorageBox<T>) { self.storage = st}
    
    @inline(__always)
    public mutating func addComponent(_ eeid: EmplaceEntityId, _ comp: T) {
        storage.add(eid: eeid.entity, component: comp)
    }

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
