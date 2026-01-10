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
    private lazy var selfStorage: PFStorage<RegistryPlatform> = 
    {
        let s = PFStorage<RegistryPlatform>()
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

    // init() {
    //     let rid = self.register(RegistryPlatform.self)
    //     guard let myStorage = self.rawGetStorage(for: rid) as? PFStorage<RegistryPlatform> 
    //     else {
    //         fatalError("cannot initialize RegistryPlatorm")
    //     }
    //     myStorage.add(eid: rid, component: self)
    // }
    

    // 實作 Platform 協議要求的原始方法
    func rawGetStorage(for rid: EntityId) -> AnyPlatformStorage? {
        if rid.id == 0 {
            return selfStorage
        }
        return nil
    }

    static func createPFStorage() -> any AnyPlatformStorage {
        return PFStorage<Self>()
    }
}