// main platform
class BasePlatform : Platform {
    var storages: [AnyPlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> AnyPlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}

enum ManifestItem {
    case Public_Component( (Component.Type, (() -> any Component) ) )
    case Private_Component( (Component.Type, (() -> any Component) ) )
    case Not_Need_Instance( Component.Type )
}

struct Manifest {
    let requirements: [ ManifestItem ]
}

extension ManifestItem {
    // 統一提取型別與實例/工廠函數
    var componentMetadata: (type: any Component.Type, instance: (() -> any Component)? ) {
        switch self {
        case .Public_Component(let (type, c)),
             .Private_Component(let (type, c)):
            return (type, c)
        case .Not_Need_Instance(let type):
            return (type, nil)
        }
    }

    var CompType: any Component.Type {
        switch self {
        case .Public_Component(let (ct, _)),
             .Private_Component(let (ct, _)),
             .Not_Need_Instance(let ct):
            return ct
            
        }
    }
}

struct EntityBuildTokens {
    fileprivate let manifest: Manifest
    let rids: [RegistryId]
}

enum IDItem {
    case Public(RegistryId)
    case Private(RegistryId)
    case Not_Need_Instance(RegistryId)
}

struct IDCard {
    let eid: EntityId
    fileprivate let manifest: Manifest
    fileprivate let rids: [RegistryId]
    fileprivate let itemRids: [IDItem]
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
            let newT_storage =  newT.createPFStorage()
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
        var item_rids: [IDItem] = []

        // 3. 遍歷 tokens 中的需求與對應的 rids
        for (index, item) in tokens.manifest.requirements.enumerated() {
            let rid = tokens.rids[index]
            switch item {
            case .Public_Component: item_rids.append( .Public( rid ) )
            case .Private_Component: item_rids.append( .Private( rid ))
            case .Not_Need_Instance: item_rids.append( .Not_Need_Instance( rid ))
            }
            
            let meta = item.componentMetadata
            // 4. 取得對應的 Storage 並存入實例
            guard let storage = self.rawGetStorage(for: rid) else {
                fatalError("Storage missing for rid=\(rid.id), type=\(meta.type)")
            }

            if let fn = meta.instance {
                storage.rawAdd(eid: newEid, component: fn())
            }
        }
        
        return IDCard(eid: newEid, manifest: tokens.manifest, rids: tokens.rids,itemRids: item_rids)
    }
}


final class Proxy {
    fileprivate let idcard: IDCard
    unowned private let _base: BasePlatform

    init(idcard: IDCard, _base: BasePlatform) {
        self.idcard = idcard
        self._base = _base
    }

    @inlinable
    func get<T: Component>(at: Int) -> T? {
        guard _base.entities!.isValid(idcard.eid) else {
            fatalError("Logic Error: try to access a dead (Entity \(idcard.eid))!")
        }
        let item = idcard.itemRids[at]
        switch item {
        case .Private, .Not_Need_Instance:
            return nil
        case .Public(let rid):
            return _base.rawGetStorage(for: rid)!.get(idcard.eid) as? T
        }
    }

    @inlinable
    func get(at: Int) -> (any Component)? {
        guard _base.entities!.isValid(idcard.eid) else {
            fatalError("Logic Error: try to access a dead (Entity \(idcard.eid))!")
        }
        let item = idcard.itemRids[at]
        switch item {
        case .Private, .Not_Need_Instance:
            return nil
        case .Public(let rid):
            return _base.rawGetStorage(for: rid)!.get(idcard.eid) as? any Component
        }
    }


    fileprivate var maxRid: Int {
        var max = 0
        for rid in idcard.rids {
            max = rid.id > max ? rid.id : max
        }
        return max
    }

    fileprivate func findTypeAt(_ targetRid: RegistryId) -> Int? {
        for (at, rid) in idcard.rids.enumerated() {
            if rid == targetRid { return at }
        }
        return nil
    }

    fileprivate var registry: Platform_Registry {
        _base.registry!
    }
}

extension BasePlatform {
    @inlinable
    func isValid(eid: EntityId) -> Bool {
        let entities = self.entities!
        return entities.isValid(eid)
    }

    func createProxy(idcard: IDCard) -> Proxy
    {
        guard isValid(eid: idcard.eid) else {
            fatalError("invalid idCard in create proxy phase")
        }

        return Proxy(idcard: idcard, _base: self)
    }
}


final class Sub_BasePlatform: BasePlatform {
    private let proxy: Proxy
    
    init(proxy: Proxy) {
        self.proxy = proxy
        super.init()

        var rawStorage: [AnyPlatformStorage?] = []
        rawStorage.append(contentsOf: repeatElement(nil, count: proxy.maxRid + 1))

        for (at, ele) in proxy.idcard.itemRids.enumerated() {
            var CompType: any Component.Type
            switch ele {
            case .Public,
                 .Not_Need_Instance:
                // not private type
                CompType = proxy.idcard.manifest.requirements[at].CompType
            case .Private:
                continue
            }

            // not private type
            let rid = proxy.idcard.rids[at]
            if let comp = proxy.get(at: at) {
                // here is public
                // maxRid + 1 gaurantee that insert is valid
                rawStorage[rid.id] = CompType.createPFStorage()
                // store comp to storage
                rawStorage[rid.id]!.rawAdd(eid: proxy.idcard.eid, component: comp)
                
                // check if it is a storage
                if let storageProvider = comp as? StorageTypeProvider {
                    let innerType = storageProvider.storedComponentType
                    
                    guard proxy.registry.contains(innerType) else {
                        fatalError("not registry for T:(\(innerType)) means does not need st<T> component")
                    }
                    let innerTypeRid = proxy.registry.register(innerType)

                    guard proxy.findTypeAt(innerTypeRid) != nil else {
                        fatalError("not apply for T:(\(innerType)) means does not need st<T> component")
                    }
                    
                    let storage = comp as! AnyPlatformStorage
                    rawStorage[innerTypeRid.id] = storage
                }
            }
            
            // not need instance
            // do not need to do anything
        }

        self.storages = rawStorage
    }
    
}