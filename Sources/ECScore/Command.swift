enum WorldCommand {
    case spawn
    case despwan(EntityId)
    // case addEntitiyComponent(EntityId, AnyVal)
}

enum WorldEvent {
    case didSpawn(EntityId)
    case didDespawn(EntityId)
    case didAddEntityComponent(EntityId, ComponentId)
    case didRemoveEntityComponent(EntityId, ComponentId)
}

enum WorldError: Error, Equatable {
    case worldNotHasComponet(ComponentId)
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
