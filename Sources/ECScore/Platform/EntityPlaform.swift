public protocol Platform_Entity: Platform, Component, AnyObject {
    func spawn(_: Int) -> [EntityId]
    func despawn(_: EntityId)
    func forEachLiveId(_ body: (EntityId) -> Void)
    func isValid(_ eid: EntityId) -> Bool
}

public class EntityPlatForm_Ver0: Platform_Entity, Component {
    private var entities = Entities()
    public init() {}

    public func isValid(_ eid: EntityId) -> Bool {
        return entities.isValid(eid)
    }

    public func spawn(_ n: Int) -> [EntityId] {
        entities.spawn(n)
    }

    public func despawn(_ eid: EntityId) {
        entities.despawn(eid)
    }

    public static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }

    public func forEachLiveId(_ body: (EntityId) -> Void) {
        for i in 0..<entities.maxId {
            if entities.idIsActive(i) {
                body(EntityId(id: i, version: entities.getVersion(i)))
            }
        }
    }
}