typealias RegistryId = EntityId

protocol Platform_Registry: AnyObject, Component {
    func register(_ type: Any.Type) -> RegistryId
    func contains(_ type: Any.Type) -> Bool
    var count: Int { get }
}

final class RegistryPlatform : Platform, Platform_Registry, Component {
    let entities: Entities = Entities()
    private var typeToId: [ObjectIdentifier: EntityId] = [:]
    var count : Int { entities.liveCount }

    // 唯一的具體存儲：只存 Registry 自己
    private lazy var selfStorage: PFStorageBox<RegistryPlatform> = 
    {
        let s =  PFStorageBox(PFStorageHandle<RegistryPlatform>())
        return s
    }()

    func register(_ type: Any.Type) -> RegistryId 
    {
        let typeId = ObjectIdentifier(type)
        if let tid = typeToId[typeId] { return tid }
        
        let eid = entities.spawn(1)[0]
        typeToId[typeId] = eid
        return eid
    }

    func contains(_ type: Any.Type) -> Bool {
        let typeId = ObjectIdentifier(type)
        return typeToId[typeId] != nil
    }

    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorageBox(PFStorageHandle<Self>())
    }
}