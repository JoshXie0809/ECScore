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
    var entities: [EntityId] { get }
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

    func containsStorage<T: Component>(_ type: T.Type) -> Bool {
        let id = ObjectIdentifier(T.self)
        return storages[id] != nil
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

// Query Builder
final class QueryDraft {
    private let world: World
    private var withSet = Set<ObjectIdentifier>()
    private var withoutSet = Set<ObjectIdentifier>()
    private var withTasks: [ObjectIdentifier] = []
    private var withoutTasks: [ObjectIdentifier] = []

    fileprivate init(_ world: World) {
        self.world = world
    }

    func with<T: Component>(_ type: T.Type) -> Self {
        let id = ObjectIdentifier(type)

        guard !withSet.contains(id) else { return self }
        guard !withoutSet.contains(id) else { return self }

        guard world.containsStorage(type) else {
            #if DEBUG
            print("⚠️ QueryDraft: storage for \(type) not found")
            #endif
            return self
        }

        withSet.insert(id)
        withTasks.append(id)
        return self
    }

    func without<T: Component>(_ type: T.Type) -> Self {
        let id = ObjectIdentifier(type
        )
        guard !withSet.contains(id) else { return self }
        guard !withoutSet.contains(id) else { return self }
        guard world.containsStorage(type) else {
            #if DEBUG
            print("⚠️ QueryDraft: storage for \(type) not found")
            #endif
            return self
        }
        withoutSet.insert(id)
        withoutTasks.append(id)
        return self
    }

    func buildQuery() -> Query {
        Query(world: world, withTasks: withTasks, withoutTasks: withoutTasks)
    }
}

struct Query {
    let world: World
    let with: [ObjectIdentifier]
    let without: [ObjectIdentifier]

    init(
        world: World,
        withTasks: [ObjectIdentifier], 
        withoutTasks: [ObjectIdentifier]) 
    {
        let with = withTasks.sorted() 
            { id1, id2 in
                let count1 = world.storages[id1]?.count ?? 0
                let count2 = world.storages[id2]?.count ?? 0
                return count1 < count2
            }
        
        let without = withoutTasks.sorted() 
            { id1, id2 in
                let count1 = world.storages[id1]?.count ?? 0
                let count2 = world.storages[id2]?.count ?? 0
                return count1 > count2
            }
        
        self.world = world
        self.with = with
        self.without = without
    }

    func query() -> [EntityId] {
        #if DEBUG
            print("Guard1")
        #endif
        // no set constraint
        guard with.count != 0 || without.count != 0 else {
            // here is with: [], without: []
            var entityList: [EntityId] = []
            entityList.reserveCapacity(world.entityCount)
            for e in world.activeEntities {
                entityList.append(e)
            }
            return entityList
        }

        #if DEBUG
            print("Guard2")
        #endif
        // here is with: [], without: [...]
        // here is with: [...], without: []
        // here is with: [...], without: [...]
        guard !(with.count == 0 && without.count != 0) else {
            // here is with: [], without: [...]
            var entityList: [EntityId] = []
            entityList.reserveCapacity(world.entityCount)
            for e in world.activeEntities {
                entityList.append(e)
            }

            var withoutStorages: [AnyStorage] = []
            for id in without {
                if let storage = world.storages[id] {
                    withoutStorages.append(storage)
                }
            }
            #if DEBUG
                print(withoutStorages)
            #endif
            
            return entityList.filter { EntityId in 
                for storage in withoutStorages {
                    if(storage.contains(EntityId)) {
                        return false
                    }
                }

                return true
            }
            
        }


        #if DEBUG
            print("Finally")
        #endif

        // here is with: [...], without: []
        // here is with: [...], without: [...]
        var withStorages: [AnyStorage] = []
        var withoutStorages: [AnyStorage] = []
        for id in with {
            if let storage = world.storages[id] {
                withStorages.append(storage)
            }
        }

        for id in without {
            if let storage = world.storages[id] {
                withoutStorages.append(storage)
            }
        }

        #if DEBUG
            print(withStorages)
            print(withoutStorages)
        #endif

        // has at least 1 with
        let baseEntityList = withStorages[0].entities

        return baseEntityList.filter { EntityId in 
            // with
            for i in 1..<withStorages.count {
                if !withStorages[i].contains(EntityId) {
                    return false
                }
            }
            // without
            for storage in withoutStorages {
                if storage.contains(EntityId) {
                    return false
                }
            }
            return true
        }
    }
}


extension World {
    func queryDraft() -> QueryDraft {
        QueryDraft(self)
    }
}