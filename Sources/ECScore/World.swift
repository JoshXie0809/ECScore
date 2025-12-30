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
    // 用 Set 來快速檢查重複
    private var withSet = Set<ObjectIdentifier>()
    private var withoutSet = Set<ObjectIdentifier>()
    // 用 Array 來保持順序（雖然最後 Query 會重排，但保持輸入順序是好習慣）
    private var withTasks: [ObjectIdentifier] = []
    private var withoutTasks: [ObjectIdentifier] = []

    fileprivate init(_ world: World) {
        self.world = world
    }

    func with<T: Component>(_ type: T.Type) -> Self {
        let id = ObjectIdentifier(type)

        // 避免重複添加 & 避免邏輯衝突（同時 require 又 without）
        guard !withSet.contains(id) else { return self }
        guard !withoutSet.contains(id) else { return self }

        // ⚡️ 修改點：移除 world.containsStorage 檢查
        // 即使現在沒有這個 Storage，也要記錄下來，讓 Query 知道「我需要這個組件」
        // 如果 Query 發現它不存在，Query 自然會回傳空陣列，這才是正確的邏輯。

        withSet.insert(id)
        withTasks.append(id)
        return self
    }

    func without<T: Component>(_ type: T.Type) -> Self {
        let id = ObjectIdentifier(type)
        
        guard !withSet.contains(id) else { return self }
        guard !withoutSet.contains(id) else { return self }
        
        // ⚡️ 修改點：移除 world.containsStorage 檢查
        // 即使 Storage 不存在，記錄「排除它」也是安全的（排除一個不存在的東西 = 沒影響）

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

    init(world: World, withTasks: [ObjectIdentifier], withoutTasks: [ObjectIdentifier]) {
        self.world = world
        
        // 🌟 保留你的優化邏輯：數量少的優先（Intersection 優化）
        self.with = withTasks.sorted { id1, id2 in
            let count1 = world.storages[id1]?.count ?? 0
            let count2 = world.storages[id2]?.count ?? 0
            return count1 < count2
        }
        
        // 🌟 保留你的優化邏輯：數量多的優先（Rejection 優化）
        self.without = withoutTasks.sorted { id1, id2 in
            let count1 = world.storages[id1]?.count ?? 0
            let count2 = world.storages[id2]?.count ?? 0
            return count1 > count2
        }
    }

    func query() -> [EntityId] {
        // Case 1: 沒有任何限制，回傳全部 Active Entities
        guard !with.isEmpty || !without.isEmpty else {
            return Array(world.activeEntities)
        }

        // 預先抓取 Without Storages (如果 storage 為 nil 則自動過濾掉)
        let withoutStorages = without.compactMap { world.storages[$0] }

        // Case 2: 只有 Without 限制
        // 我們必須遍歷所有 Active Entities，然後剔除符合 without 的
        if with.isEmpty {
            return world.activeEntities.filter { entityId in
                for storage in withoutStorages {
                    if storage.contains(entityId) { return false }
                }
                return true
            }
        }

        // Case 3: 有 With 限制 (最常見的情況)
        
        // ⚡️ 步驟 A：嘗試獲取所有 With 的 Storage
        let withStorages = with.compactMap { world.storages[$0] }

        // ⚡️ 步驟 B (關鍵修正)：安全檢查
        // 如果抓到的 storage 數量少於要求的數量，代表有「必要的組件」目前不存在。
        // 例如：要求 [Position, Velocity]，但 Velocity storage 是 nil。
        // 這時交集必定為空，直接回傳 []。這避免了存取 array[0] 的崩潰，也修正了邏輯錯誤。
        guard withStorages.count == with.count else {
            return []
        }

        // ⚡️ 步驟 C：選定 Base Set
        // 因為我們在 init 已經做過排序 (sorted)，所以 [0] 必定是實體數量最少的 Storage。
        let baseEntities = withStorages[0].entities

        // ⚡️ 步驟 D：進行過濾
        return baseEntities.filter { entityId in
            // 1. 檢查其餘的 With 條件 (Intersection)
            // 從 index 1 開始，因為 index 0 是 base
            for i in 1..<withStorages.count {
                if !withStorages[i].contains(entityId) {
                    return false
                }
            }

            // 2. 檢查 Without 條件 (Exclusion)
            for storage in withoutStorages {
                if storage.contains(entityId) {
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