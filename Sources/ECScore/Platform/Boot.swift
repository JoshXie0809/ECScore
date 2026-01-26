enum PlatformReservedSlot: Int { case registry = 0, entities = 1 }

extension BasePlatform {
    func boot<R: Platform_Registry, E: Platform_Entity>(registry: R, entities: E) {
        self.storages = [nil, nil]
        
        // expected rid.id = 0
        let registryPlatformId = registry.register(R.self)

        // expected rid.id = 1
        // pf_entity register itself to rg_pf
        let entityPlatformId = registry.register(E.self)

        // create storage for base pf
        var r_storage = R.createPFStorage()
        var e_storage = E.createPFStorage()
        
        // entityId 0
        let eid0 = entities.spawn(1)[0]
        
        precondition(eid0 == EntityId(id: 0, version: 0))
        precondition(registryPlatformId == RegistryId(id: PlatformReservedSlot.registry.rawValue, version: 0))
        precondition(entityPlatformId == RegistryId(id: PlatformReservedSlot.entities.rawValue, version: 0))

        // add eid 0 to r_storage, e_storage
        // they are public resourse (or at eid 0, it will be plublic resource)
        r_storage.rawAdd(eid: eid0, component: registry)
        e_storage.rawAdd(eid: eid0, component: entities)

        // add two storage to list
        self.storages[registryPlatformId.id] = r_storage
        self.storages[entityPlatformId.id] = e_storage
    }
}

extension BasePlatform {
    @inlinable
    var registry: Platform_Registry? {
        let rid0 = RegistryId(id: 0, version: 0)
        let eid0 = EntityId(id: 0, version: 0)
        // 直接找 0 號位並嘗試轉型
        guard let storage = self.storages[rid0.id] else {
            return nil
        }

        return storage.get(eid0) as? Platform_Registry
    }

    @inlinable
    var entities: Platform_Entity? {
        let rid1 =  RegistryId(id: 1, version: 0)
        let eid0 = EntityId(id: 0, version: 0)
        guard let storage = self.storages[rid1.id] else {
            return nil
        }

        return storage.get(eid0) as? Platform_Entity
    }
}

