protocol Platform_Entitiy: Platform, Component, AnyObject {
    func spawn(_: Int) -> [EntityId]
    func despawn(_: EntityId)
    func forEachLiveId(_ body: (EntityId) -> Void)
    func isValid(_ eid: EntityId) -> Bool
}

class EntitiyPlatForm_Ver0: Platform_Entitiy, Component {
    private var entities = Entities()
    private lazy var selfStorage: PFStorage<EntitiyPlatForm_Ver0> = 
    {
        let s = PFStorage<EntitiyPlatForm_Ver0>()
        return s
    }()

    func isValid(_ eid: EntityId) -> Bool {
        return entities.isValid(eid)
    }

    func spawn(_ n: Int) -> [EntityId] {
        entities.spawn(n)
    }

    func despawn(_ eid: EntityId) {
        entities.despawn(eid)
    }

    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<Self>()
    }

    func forEachLiveId(_ body: (EntityId) -> Void) {
        for i in 0..<entities.maxId {
            if entities.idIsActive(i) {
                body(EntityId(id: i, version: entities.getVersion(i)))
            }
        }
    }
}