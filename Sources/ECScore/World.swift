struct EntityId: Hashable {
    let id: Int
    let version: Int
}

extension EntityId: CustomStringConvertible {
    var description: String {
        "E(id:\(id), v:\(version))"
    }
}

final class World {
    fileprivate var storages: [ObjectIdentifier:AnyStorage] = [:]
    fileprivate var resources: [ObjectIdentifier:Any] = [:]
    fileprivate let entities = EntityManager()
}

final class EntityManager {
}


protocol AnyStorage: AnyObject {
    var componentType: ObjectIdentifier { get }
    var count: Int { get }
    func removeEntity(_: EntityId)
    func contains(_: EntityId) -> Bool
}
