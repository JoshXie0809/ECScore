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
        activeEntities.count
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
        entities.count
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
        for storage in storages.values {
            storage.removeEntity(entitiy)
        }
        entities.destroyEntity(entitiy)
    }
}

protocol AnyStorage: AnyObject {
    var componentType: Any.Type { get }
    var count: Int { get }
    func removeEntity(_: EntityId)
    func contains(_: EntityId) -> Bool
}

extension World {
    func addStorage<T: Component>(_ storage: Storage<T>) {
        let id = ObjectIdentifier(T.self)
        guard storages[id] == nil else {
            return
        }
        storages[id] = storage
    }

    subscript<T: Component>(_ type: T.Type) -> Storage<T> {
        let id = ObjectIdentifier(type)
        guard let storage = storages[id] as? Storage<T> else {
            let newStorage = Storage<T>()
            storages[id] = newStorage
            return newStorage
        }
        return storage
    }

    func destroyStorage<T: Component>(_ type: T.Type) {
        let id = ObjectIdentifier(T.self)
        guard storages[id] != nil else {
            return
        }

        storages.removeValue(forKey: id)
    }

    var storageCount : Int {
        storages.count
    }
}



extension World: CustomStringConvertible {
    var description: String {
return """
World(n: \(entityCount)) {
    storages: \(storages.values)
}
"""
    }
}

// Query system 
final class Query {
    private let world: World
    private var withSet = Set<ObjectIdentifier>()
    private var withoutSet = Set<ObjectIdentifier>()

    private(set) var withTasks: [ObjectIdentifier] = []
    private(set) var withoutTasks: [ObjectIdentifier] = []

    init(_ world: World) {
        self.world = world
    }

    func with<T: Component>(_ type: T.Type) -> Query {
        let id = ObjectIdentifier(type)

        guard !withSet.contains(id) else { return self }
        guard !withoutSet.contains(id) else { return self }
        guard world.storages[id] != nil else {
            return self
        }

        withSet.insert(id)
        withTasks.append(id)
        return self
    }

    func without<T: Component>(_ type: T.Type) -> Query {
        let id = ObjectIdentifier(type
        )
        guard !withSet.contains(id) else { return self }
        guard !withoutSet.contains(id) else { return self }
        guard  world.storages[id] != nil else {
            return self
        }
        withoutSet.insert(id)
        withoutTasks.append(id)
        return self
    }
}


extension World {
    // 簡單的查詢：回傳同時擁有 A 與 B 的實體
    func query<A: Component, B: Component>(_ typeA: A.Type, _ typeB: B.Type) -> [(EntityId, A, B)] {
        let storageA = self[A.self]
        let storageB = self[B.self]
        
        // 效能優化策略：從數量少的 Storage 開始遍歷 (Smallest Storage First)
        if storageA.count <= storageB.count {
                return storageA.activeEntities.compactMap { id in
                    guard let compB = storageB.getEntity(id) else { return nil } // 你需要實作 storage.get
                    return (id, storageA.getEntity(id)!, compB)
            }
        } else {
            return storageB.activeEntities.compactMap { id in
                guard let compA = storageA.getEntity(id) else { return nil } // 你需要實作 storage.get
                return (id, compA, storageB.getEntity(id)!)
            }
        }
    }
}