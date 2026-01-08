extension BasePlatform {
    func boot<E: Platform_Entitiy>(registry: RegistryPlatform, entities: E) {
        self.storages = [nil, nil]
        
        // expected rid.id = 0
        let registryPlatformId = registry.register(RegistryPlatform.self)

        // expected rid.id = 1
        // pf_entity register itself to rg_pf
        let entityPlatformId = registry.register(Platform_Entitiy.self)

        // create storage for base pf
        let r_storage = Storage<RegistryPlatform>()
        let e_storage = Storage<E>()

        
        // entityId 0
        let eid0 = entities.spawn(1)[0]
        // add eid 0 to r_storage
        r_storage.addEntity(newEntity: eid0, registry)

        let eid1 = entities.spawn(1)[0]
        e_storage.addEntity(newEntity: eid1, entities)

        // add two storage to list
        self.storages[registryPlatformId.id] = r_storage
        self.storages[entityPlatformId.id] = e_storage
    }
}