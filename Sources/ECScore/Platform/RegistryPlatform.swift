typealias RegistryId = EntityId

class RegistryPlatform : Platform, Component {
    let entities = Entities()
    private var typeToId: [ObjectIdentifier: EntityId] = [:]

    // 唯一的具體存儲：只存 Registry 自己
    private lazy var selfStorage: Storage<RegistryPlatform> = {
        let s = Storage<RegistryPlatform>()
        return s
    }()

    func registry<T: Component>(_ type: T.Type) -> RegistryId {
        let typeId = ObjectIdentifier(type)
        if let tid = typeToId[typeId] { return tid }
        
        let eid = entities.spawn(1)[0]
        typeToId[typeId] = eid
        return eid
    }

    init() {
        let rid = self.registry(RegistryPlatform.self)
        
        guard let myStorage = self.getStorage(for: rid) as? Storage<RegistryPlatform> else {
            fatalError("無法初始化 Registry 儲存空間")
        }

        myStorage.addEntity(newEntity: rid, self)
    }

    // 實作 Platform 協議要求的原始方法
    func getStorage(for rid: EntityId) -> PlatformStorage? {
        if rid.id == 0 {
            return selfStorage
        }
        return nil
    }
}