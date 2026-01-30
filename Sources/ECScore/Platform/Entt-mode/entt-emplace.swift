extension TypeToken {
    @inlinable
    func getStorage(
        base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    ) -> PFStorageBox<T>
    {
        base.value.storages[rid.id] as! PFStorageBox<T>
    }
}

@inline(__always)
func emplace<each T>(
    _ base: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    tokens: borrowing (repeat TypeToken<each T>),
    _ fn: (borrowing EmplaceEntities, borrowing EmplacePack<repeat each T> ) -> Void) 
{
    let pack = EmplacePack((repeat EmplaceStorage((each tokens).getStorage(base: base))))
    fn( EmplaceEntities(base.entities), pack )
}

struct EmplaceEntityId {
    fileprivate let entity: EntityId
    fileprivate init(_ eid: EntityId) { self.entity = eid }
}

struct EmplaceEntities: ~Copyable {
    private let entities: Platform_Entity
    fileprivate init(_ entities: Platform_Entity) { self.entities = entities}
    @inlinable
    func createEntity() -> EmplaceEntityId {
        EmplaceEntityId(entities.spawn(1)[0])
    }
}

struct EmplaceStorage<T: Component> {
    private var storage: PFStorageBox<T>
    fileprivate init(_ st: PFStorageBox<T>) { self.storage = st}
    @inlinable
    mutating func addComponent(_ eeid: EmplaceEntityId, _ comp: T) {
        storage.add(eid: eeid.entity, component: comp)
    }
}

struct EmplacePack<each T: Component>: ~Copyable {
    // 將所有 Storage 放在一個元組裡
    let storages: (repeat EmplaceStorage<each T>)
    fileprivate init(_ sts: (repeat EmplaceStorage<each T>)) { self.storages = sts }
}
