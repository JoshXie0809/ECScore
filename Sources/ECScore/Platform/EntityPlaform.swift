public protocol Platform_Entity: Platform, Component, AnyObject {
    func spawn(_: Int) -> [EntityId]
    func despawn(_: EntityId)
    func forEachLiveId(_ body: (EntityId) -> Void)
    func isValid(_ eid: EntityId) -> Bool
    func getActiveEntitiesMask_Uncheck(_ block: Int) -> UInt64
    var maxId: Int { get }
}

public class EntityPlatForm_Ver0: Platform_Entity, Component {
    @inline(__always)
    private var entities = Entities()
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
    public func getActiveEntitiesMask_Uncheck(_ block: Int) -> UInt64 {
        entities.getActiveEntitiesMask_Uncheck(block)
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