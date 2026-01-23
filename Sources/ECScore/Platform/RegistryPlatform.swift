typealias RegistryId = EntityId

protocol Platform_Registry: AnyObject, Component {
    func register(_ type: Any.Type) -> RegistryId
    func lookup(_ type: Any.Type) -> RegistryId?
    func contains(_ type: Any.Type) -> Bool
    var count: Int { get }
}

class RegistryPlatform : Platform, Platform_Registry, Component {
    let entities: Entities = Entities()
    private var typeToRId: [ObjectIdentifier: RegistryId] = [:]
    var count : Int { entities.liveCount }

    func register(_ type: Any.Type) -> RegistryId {
        let typeId = ObjectIdentifier(type)
        if let rid = typeToRId[typeId] { return rid }
        
        let rid: RegistryId = entities.spawn(1)[0]  
        typeToRId[typeId] = rid
        return rid
    }

    func lookup(_ type: any Any.Type) -> RegistryId? {
        let typeId = ObjectIdentifier(type)
        if let rid = typeToRId[typeId] { return rid }
        return nil
    }

    func contains(_ type: Any.Type) -> Bool {
        let typeId = ObjectIdentifier(type)
        return typeToRId[typeId] != nil
    }

    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }
}
