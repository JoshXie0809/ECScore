protocol Platform_Entitiy: Platform, Component {
    func spawn(_: Int) -> [EntityId]
    func despawn(_: EntityId)
}

class EntitiyPlatForm_Ver0: Platform_Entitiy, Component {
    private var entities = Entities()

    private lazy var selfStorage: Storage<EntitiyPlatForm_Ver0> = 
    {
        let s = Storage<EntitiyPlatForm_Ver0>()
        return s
    }()

    func rawGetStorage(for rid: RegistryId) -> (any PlatformStorage)? {
        if rid.id == 1 {
            return selfStorage
        }
        return nil
    }

    func spawn(_ n: Int) -> [EntityId] {
        entities.spawn(n)
    }

    func despawn(_ eid: EntityId) {
        entities.despawn(eid)
    }
}