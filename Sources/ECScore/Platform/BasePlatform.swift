class BasePlatform : Platform {
    var storages: [AnyPlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> AnyPlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}

enum ManifestItem {
    case Public_Component( (Component.Type, Component) )
    case Private_Component( (Component.Type, Component) )
}

struct Manifest {
    let requirements: [ ManifestItem ]
}

extension ManifestItem {
    // 統一提取型別與實例/工廠函數
    var componentMetadata: (type: any Component.Type, instance: Any) {
        switch self {
        case .Public_Component(let (type, c)),
             .Private_Component(let (type, c)):
            return (type, c)
        }
    }
}

struct EntityBuildTokens {
    fileprivate let manifest: Manifest
    let rids: [RegistryId]
}

struct IDCard {
    let eid: EntityId
    fileprivate let rids: [RegistryId]
}

extension BasePlatform {
    func interop(manifest: Manifest) -> EntityBuildTokens {
        guard let registry = registry else {
            fatalError("Platform Registry not found during interop phase")
        }
        var rids: [RegistryId] = []
        var newTypes: [any Component.Type] = []

        for item in manifest.requirements {
            let meta = item.componentMetadata
            if !registry.contains(meta.type) {
                newTypes.append(meta.type)
            }

            let rid = registry.register(meta.type)
            rids.append(rid)
        }
        // prepare to build storage
        Self.ensureStorageCapacity(base: self)
        // storages length is ensured
        for newT in newTypes {
            let newT_storage =  openAndCreateStorage(newT)
            let rid = registry.register(newT)
            self.storages[rid.id] = newT_storage
        }

        return EntityBuildTokens(manifest: manifest, rids: rids)
    }

    private static func ensureStorageCapacity(base: BasePlatform) {
        let registry = base.registry! // check while interop start
        let rid_count = registry.count
        let needed = rid_count - base.storages.count
        
        if needed > 0 {
            base.storages.append( contentsOf: repeatElement(nil, count: needed) )
        }
    }

    private func openAndCreateStorage(_ type: any Component.Type) -> any AnyPlatformStorage {
        func helper<T: Component>(_ concreteType: T.Type) -> any AnyPlatformStorage {
            return T.createPFStorage()
        }
        return helper(type)
    }
    
}

extension BasePlatform {
    /// 根據 tokens 真正建立實體並填入組件
    func build(from tokens: EntityBuildTokens) -> IDCard {
        // 1. 取得 Entity 平台以進行 spawn
        guard let entities = self.entities else {
            fatalError("Platform Entities not found during build phase")
        }
        
        // 2. 生成一個新的實體 ID
        let newEid = entities.spawn(1)[0]
        
        // 3. 遍歷 tokens 中的需求與對應的 rids
        for (index, item) in tokens.manifest.requirements.enumerated() {
            let rid = tokens.rids[index]
            let meta = item.componentMetadata
            
            // 4. 取得對應的 Storage 並存入實例
            if let storage = self.rawGetStorage(for: rid) {
                storage.rawAdd(eid: newEid, component: meta.instance)
            }
        }
        
        return IDCard(eid: newEid, rids: tokens.rids)
    }
}