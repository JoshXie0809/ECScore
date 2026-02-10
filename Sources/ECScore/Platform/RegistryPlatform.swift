public typealias RegistryId = EntityId

public protocol Platform_Registry: AnyObject, Component {
    func register(_ type: any Component.Type) -> RegistryId
    func lookup(_ type_rs: TypeStrIdHashed_FNV1A_64) -> RegistryId?
    func lookup(_ rid: RegistryId) -> Component.Type?
    func contains(_ type: any Component.Type) -> Bool
    var maxRidId: Int { get }
    var count: Int { get }
}

public final class RegistryPlatform : Platform, Platform_Registry, Component {
    let entities: Entities = Entities()
    private var typeToRId: [TypeStrIdHashed_FNV1A_64: RegistryId] = [:]
    private var ridToType: [RegistryId: any Component.Type] = [:]
    public var maxRidId : Int { entities.maxId }
    public var count : Int { entities.maxId + 1 }
    public init() {}

    public func register(_ type: any Component.Type) -> RegistryId {
        let _hs = type._hs
        if let rid = typeToRId[_hs] { return rid }
        
        let rid: RegistryId = entities.spawn(1)[0]
        ridToType[rid] = type
        typeToRId[_hs] = rid
        return rid
    }

    public func lookup(_ type_rs: TypeStrIdHashed_FNV1A_64) -> RegistryId? {
        return typeToRId[type_rs]
    }

    public func lookup(_ rid: RegistryId) -> (any Component.Type)? {
        return ridToType[rid]
    }

    public func contains(_ type: any Component.Type) -> Bool {
        return typeToRId[type._hs] != nil
    }

    public static func createPFStorage() -> AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }
}
