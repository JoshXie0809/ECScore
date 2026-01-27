struct ComponentId: Hashable, Sendable {
    let raw: ObjectIdentifier
    init<T: Component>(_ type: T.Type) {
        self.raw = ObjectIdentifier(type)
    }
    init(_ raw: ObjectIdentifier) {
        self.raw = raw
    }
}

final class Storage<T: Component>: AnyStorage {
    private var sparse: [EntityId:Int] = [:]
    private var dense: ContiguousArray<T> = []
    // dense id to entity id
    private(set) var entities: ContiguousArray<EntityId> = []
    var components: ContiguousArray<T> { dense }
    var componentId: ComponentId {
        ComponentId(T.self)
    }
    
    var count: Int { dense.count }
    var componentType: Component.Type {
        T.self
    }

    @inlinable
    func contains(_ id: EntityId) -> Bool {
        sparse[id] != nil
    }

    @discardableResult
    func removeEntity(_ removeEntity: EntityId) -> Bool {
        guard let removeIndex = sparse[removeEntity] 
        else {
            return false
        }

        // swap item at lastIndex to removeIndex
        let lastIndex = count - 1
        if removeIndex < lastIndex {
            let lastEntityId = entities[lastIndex]
            // update 3 places
            dense[removeIndex] = dense[lastIndex]
            entities[removeIndex] = lastEntityId
            sparse[lastEntityId] = removeIndex
        }

        // remove 3 places
        dense.removeLast()
        entities.removeLast()
        sparse.removeValue(forKey: removeEntity)
        return true
    }

    func addEntity(newEntity: EntityId, _ anyComponent: any Component) {
        guard let c = anyComponent as? T else {
            // 這代表你的 storage 字典或 cid 對錯了，屬於「不應該發生」的 internal error
            preconditionFailure("Component type mismatch: expected \(T.self), got \(type(of: anyComponent))")
        }

        addEntity(newEntity: newEntity, c) // 呼叫有型別的 addEntity
    }

    func addEntity(newEntity: EntityId, _ component: T) {
        // add is for insert new entity, doesnot update exist entity
        guard !contains(newEntity) else {
            return
        }

        // insert new entity to 3 places
        // last index is count - 1
        sparse[newEntity] = count
        dense.append(component)
        entities.append(newEntity)
    }

    func alterEntity(entity: EntityId, _ transform: (inout T) -> Void) 
    {
        guard let index = sparse[entity] else {
            return
        }

        transform(&dense[index])
    }

    func getEntity(_ entity: EntityId) -> T? {
        // 1. 檢查 sparse 字典裡有沒有這個實體的索引
        guard let index = sparse[entity] else {
            return nil
        }
    
        // 2. 根據索引從連續的 dense 陣列中取出組件
        return dense[index]
    }

    

}