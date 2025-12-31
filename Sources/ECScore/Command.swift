enum WorldCommand {
    case spawn
    case despwan(EntityId)
}

struct ComponentId: Hashable, Sendable {
    let raw: ObjectIdentifier
    init<T: Component>(_ type: T.Type) {
        self.raw = ObjectIdentifier(type)
    }
    init(_ raw: ObjectIdentifier) {
        self.raw = raw
    }
}


enum WorldEvent {
    case didSpawn(EntityId)
    case didDespawn(EntityId)
    case didRemoveEntityComponent(EntityId, ComponentId)
}

enum WorldError: Error, Equatable {
    case entitiyNotAlive(EntityId)
    case entityNotHasComponent(EntityId, ComponentId)
}


struct EventView {
    let events: [WorldEvent]

    var spawnedEntities: [EntityId] {
        events.compactMap {
            if case .didSpawn(let e) = $0 { return e }
            return nil
        }
    }

    var despawnedEntities: [EntityId] {
        events.compactMap {
            if case .didDespawn(let e) = $0 { return e }
            return nil
        }
    }

    func removedComponents(of entity: EntityId) -> [ComponentId] {
        events.compactMap {
            if case .didRemoveEntityComponent(let e, let c) = $0, e == entity {
                return c
            }
            return nil
        }
    }
}
