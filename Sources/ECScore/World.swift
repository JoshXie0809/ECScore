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
    private var freeList: [Int] = []
    private var versions: [Int] = []
    private(set) var activeEntities = Set<EntityId>()
    var count: Int {
        versions.count
    }

    func createEntity() -> EntityId {
        let entity: EntityId
        if let reusedIndex = freeList.popLast() {
            // version is update when destroy entity
            let version = versions[reusedIndex]
            entity = EntityId(id: reusedIndex, version: version)

        } else {
            // no Index can reused
            let newIndex = versions.count
            let version = 0
            entity = EntityId(id: newIndex, version: version)
            versions.append(version)
        }
        
        activeEntities.insert(entity)
        return entity
    }

    func destroyEntity(_ entity: EntityId) {
        guard isValid(entity) else {
            return
        }

        let destroyIndex = entity.id
        // update version
        versions[destroyIndex] += 1
        freeList.append(destroyIndex)
        activeEntities.remove(entity)
    }

    func isValid(_ entity: EntityId) -> Bool {
        return entity.id < versions.count && versions[entity.id] == entity.version
    }
}

extension World {
    var entityCount: Int {
        activeEntities.count
    }

    var activeEntities: Set<EntityId> {
        entities.activeEntities
    }

    func createEntity() -> EntityId {
        entities.createEntity()
    }

    func contains(_ entitiy: EntityId ) -> Bool {
        entities.isValid(entitiy)
    }

    func destroyEntity(_ entitiy: EntityId) {
        entities.destroyEntity(entitiy)
    }
}

protocol AnyStorage: AnyObject {
    var componentType: Any.Type { get }
    var count: Int { get }
    func removeEntity(_: EntityId)
    func contains(_: EntityId) -> Bool
}
