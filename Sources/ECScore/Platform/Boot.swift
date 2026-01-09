extension BasePlatform {
    func boot<E: Platform_Entitiy>(registry: RegistryPlatform, entities: E) {
        self.storages = [nil, nil]
        
        // expected rid.id = 0
        let registryPlatformId = registry.register(RegistryPlatform.self)

        // expected rid.id = 1
        // pf_entity register itself to rg_pf
        let entityPlatformId = registry.register(Platform_Entitiy.self)

        // create storage for base pf
        let r_storage = PFStorage<RegistryPlatform>()
        let e_storage = PFStorage<E>()

        
        // entityId 0
        let eid0 = entities.spawn(1)[0]
        // add eid 0 to r_storage
        r_storage.add(eid: eid0, component: registry)

        let eid1 = entities.spawn(1)[0]
        e_storage.add(eid: eid1, component: entities)

        // add two storage to list
        self.storages[registryPlatformId.id] = r_storage
        self.storages[entityPlatformId.id] = e_storage
    }
}

extension Platform {
    /// 嘗試從平台中取得地圖（握手）
    var registry: RegistryPlatform? {
        let rid0 = RegistryId(id: 0, version: 0)
        // 直接找 0 號位並嘗試轉型
        guard let storage = self.rawGetStorage(for: rid0) else {
            return nil
        }

        return storage.getWithDenseIndex_Uncheck(0) as? RegistryPlatform
    }

    var entities: Platform_Entitiy? {
        let rid1 =  RegistryId(id: 1, version: 0)
        guard let storage = self.rawGetStorage(for: rid1) else {
            return nil
        }

        return storage.getWithDenseIndex_Uncheck(0) as? Platform_Entitiy
    }
}

