protocol Platform_Entitiy: Platform, Component {
    func spawn(_: Int) -> [EntityId]
    func despawn(_: EntityId)
}

class EntitiyPlatForm_Ver0: Platform_Entitiy, Component {
    private var entities = Entities()

    private lazy var selfStorage: PFStorage<EntitiyPlatForm_Ver0> = 
    {
        let s = PFStorage<EntitiyPlatForm_Ver0>()
        return s
    }()

    func spawn(_ n: Int) -> [EntityId] {
        entities.spawn(n)
    }

    func despawn(_ eid: EntityId) {
        entities.despawn(eid)
    }

    func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<Self>()
    }
}