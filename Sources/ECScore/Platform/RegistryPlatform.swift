typealias RegistryId = EntityId
// registry a tpye to a platform
// can not remove registry type
class RegistryPlatform : BasePlatform, Component {
    // the entity of RegistyPlatform is ComponentType 

    private var typeToId: [ObjectIdentifier:EntityId] = [:]

    func registry<T: Component>(_ tpye: T.Type) -> RegistryId {
        let typeId = ObjectIdentifier(tpye)

        // gaurd double registry
        guard let tid = typeToId[typeId] else {
            // init type
            let eid = entities.spawn()[0]
            typeToId[typeId] = eid
            return eid
        }
        
        return tid
    }

    override init() {
        super.init()

        let rid = self.registry(RegistryPlatform.self)
        let myStorage: Storage<RegistryPlatform> = self.getStorage(rid: rid)

        myStorage.addEntity(newEntity: rid, self)
    }

}