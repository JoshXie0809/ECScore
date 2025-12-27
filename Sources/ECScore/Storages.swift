protocol Component {}

final class Storage<T: Component>: AnyStorage {
    private var sparse: [EntityId:Int] = [:]
    private var dense: [T] = []
    // dense id to entity id
    private var entities: [EntityId] = []

    var activeEntities: [EntityId] { entities }
    var components: [T] { dense }

    var count: Int { dense.count }
    var componentType: ObjectIdentifier {
        ObjectIdentifier(T.self)
    }

    func contains(_ id: EntityId) -> Bool {
        sparse[id] != nil
    }

    func removeEntity(_ removeEntity: EntityId) {
        guard let removeIndex = sparse[removeEntity] 
        else {
            return
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

}