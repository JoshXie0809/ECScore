typealias RegistryId = EntityId

protocol Platform_Registry: AnyObject, Component {
    func register(_ type: any Component.Type) -> RegistryId
    func lookup(_ type: any Component.Type) -> RegistryId?
    func lookup(_ rid: RegistryId) -> Component.Type?
    func contains(_ type: any Component.Type) -> Bool
    var count: Int { get }
}

class RegistryPlatform : Platform, Platform_Registry, Component {
    let entities: Entities = Entities()
    private var typeToRId: [TypeStrIdHashed_FNV1A_64: RegistryId] = [:]
    private var ridToType: [RegistryId: any Component.Type] = [:]
    var count : Int { entities.liveCount }

    func register(_ type: any Component.Type) -> RegistryId {
        let _hs = type._hs
        if let rid = typeToRId[_hs] { return rid }
        
        let rid: RegistryId = entities.spawn(1)[0]
        ridToType[rid] = type
        typeToRId[_hs] = rid
        return rid
    }

    func lookup(_ type: any Component.Type) -> RegistryId? {
        return typeToRId[type._hs]
    }

    func lookup(_ rid: RegistryId) -> (any Component.Type)? {
        return ridToType[rid]
    }

    func contains(_ type: any Component.Type) -> Bool {
        return typeToRId[type._hs] != nil
    }

    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }
}
