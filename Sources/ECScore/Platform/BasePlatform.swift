// main platform
class BasePlatform : Platform {
    var storages: [AnyPlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> AnyPlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}

enum BasePlatformError: Error {
    case invalidEID
}


// 向 main base-pf 確保需要的 Type 的 storage 是存在的
typealias ComponentManifest = Array<any Component.Type>

struct InteropToken {
    let rids: [RegistryId]
    let idToAt: [ObjectIdentifier:Int]
    fileprivate init(
        rids: [RegistryId],
        idToAt: [ObjectIdentifier:Int]
    ) {
        self.rids = rids
        self.idToAt = idToAt
    }
}

@discardableResult
func interop(
    _ pf_val: Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ manifest_val: Validated<ComponentManifest, Proof_Unique, Manifest_Facts>
)
    -> InteropToken
{
    let registry = pf_val.registry
    let manifest = manifest_val.value

    var newRids: [(RegistryId, any Component.Type)] = []
    var rids: [RegistryId] = []
    var idToAt: [ObjectIdentifier:Int] = [:]

    for (at, type) in manifest.enumerated() {
        if !registry.contains(type) {
            // not contains, so register the type
            let rid = registry.register(type)
            newRids.append((rid, type))
        }
        // search registry rid
        let rid = registry.register(type)
        rids.append(rid)
        let type_id = ObjectIdentifier(type)
        idToAt[type_id] = at
    }

    // ensure storages length
    ensureStorageCapacity(base: pf_val)

    for (rid, type) in newRids {
        pf_val.value.storages[rid.id] = type.createPFStorage()
    }

    return InteropToken(rids: rids, idToAt: idToAt)
}

fileprivate func ensureStorageCapacity(
    base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>
) {
    
    let rid_count = base.registry.count
    let needed = rid_count - base.value.storages.count
    
    if needed > 0 {
        base.value.storages.append( contentsOf: repeatElement(nil, count: needed) )
    }
}

func interop<each T: Component>(
    _ pf_val: Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ type: repeat (each T).Type
) 
    -> InteropToken
{
    var manifest: ComponentManifest = []
    repeat manifest.append(each type)
    var manifest_val = Raw(value: manifest).upgrade(Manifest_Facts.self)
    validate(validated: &manifest_val, Manifest_Facts.FlagCase.unique.rawValue)
    
    guard case let .success(manifest_unique) = manifest_val.certify(Proof_Unique.self) else {
        fatalError("duplicate of type while using interop<T>")
    }

    return interop(pf_val, manifest_unique)
}

func spawnEntity(
    _ base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ n: Int = 1
) -> [EntityId]
{
    return base.entities.spawn(n)
}

struct EntityHandle {
    private let base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>
    private let eid: EntityId
    fileprivate init(base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>, eid: EntityId) {
        self.base = base
        self.eid = eid
    }
}

func getEntityHandle(
    _ base: Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ eid: EntityId
)  -> Result<EntityHandle, BasePlatformError>
{
    guard base.entities.isValid(eid) else { return .failure(.invalidEID) }
    return .success(EntityHandle(base: base, eid: eid))   
}

extension EntityHandle {
    // can use this to put data on eid
    @inlinable
    func mount<each T: Component>(_ comp: repeat @escaping (() -> each T)) {   
        let token = interop(self.base, repeat (each T).self)
        var providers: [() -> any Component] = []
        repeat providers.append(each comp)

        addComponent(token: token, providers: providers)
    }

    @usableFromInline
    internal func addComponent(token: InteropToken, providers: [() -> any Component]) {
        // interop will ensure them
        for (at, provider) in providers.enumerated() {
            let rid = token.rids[at]
            let storage = self.base.value.storages[rid.id]!
            storage.rawAdd(eid: self.eid, component: provider())
        }
    }
}






























// too-complex-so-I-will-rebuild

// enum ManifestItem {
//     case Public_Component( (Component.Type, (() -> any Component) ) )
//     case Private_Component( (Component.Type, (() -> any Component) ) )
//     case Phantom( Component.Type )
// }

// struct Manifest {
//     let requirements: [ ManifestItem ]
// }

// extension ManifestItem {
//     // 統一提取型別與實例/工廠函數
//     var componentType: any Component.Type {
//         switch self {
//         case .Public_Component(let (type, _)),
//              .Private_Component(let (type, _)),
//              .Phantom(let type):
//             return type
//         }
//     }
    
//     // 把 factory 獨立出來
//     var factory: (() -> any Component)? {
//         switch self {
//         case .Public_Component(let (_, f)),
//              .Private_Component(let (_, f)):
//             return f
//         case .Phantom:
//             return nil
//         }
//     }
// }

// extension ManifestItem {
//     var kindName: String {
//         switch self {
//         case .Public_Component:  return "Public"
//         case .Private_Component: return "Private"
//         case .Phantom:           return "Phantom"
//         }
//     }
// }

// extension Manifest {
//     /// Throws if the manifest contains duplicated component types.
//     func validateNoDuplicateTypes() throws {
//         // key: ObjectIdentifier(componentType)
//         var firstSeen: [ObjectIdentifier:(index: Int, kind: String, type: Any.Type)] = [:]
//         var duplicates: [ManifestValidationError.DuplicateTypeDetail] = []

//         for (idx, item) in requirements.enumerated() {
//             let t = item.componentType
//             let key: ObjectIdentifier = ObjectIdentifier(t)

//             if let first = firstSeen[key] {
//                 duplicates.append(.init(
//                     type: first.type,
//                     firstIndex: first.index,
//                     firstKind: first.kind,
//                     secondIndex: idx,
//                     secondKind: item.kindName
//                 ))
//             } else {
//                 firstSeen[key] = (idx, item.kindName, t)
//             }
//         }

//         if !duplicates.isEmpty {
//             throw ManifestValidationError.duplicatedComponentTypes(details: duplicates)
//         }
//     }
// }

// struct EntityBuildTokens {
//     fileprivate let manifest: Manifest
//     fileprivate let ridToAt: [Int:Int]
//     let rids: [RegistryId]
// }

// enum IDItem {
//     case Public(RegistryId)
//     case Private(RegistryId)
//     case Phantom(RegistryId)
// }

// struct IDCard {
//     let eid: EntityId
//     fileprivate let manifest: Manifest
//     fileprivate let rids: [RegistryId]
//     fileprivate let itemRids: [IDItem]
//     fileprivate let ridToAt: [Int:Int]
// }

// enum ManifestValidationError: Error, CustomStringConvertible {
//     case duplicatedComponentTypes(details: [DuplicateTypeDetail])

//     struct DuplicateTypeDetail {
//         let type: Any.Type
//         let firstIndex: Int
//         let firstKind: String
//         let secondIndex: Int
//         let secondKind: String
//     }

//     var description: String {
//         switch self {
//         case .duplicatedComponentTypes(let details):
//             let lines = details.map {
//                 "Duplicated component type: \($0.type) " +
//                 "(first: idx=\($0.firstIndex), kind=\($0.firstKind)) " +
//                 "(again: idx=\($0.secondIndex), kind=\($0.secondKind))"
//             }
//             return lines.joined(separator: "\n")
//         }
//     }
// }


// extension BasePlatform {
//     /// 根據 tokens 真正建立實體並填入組件
//     func build(from tokens: EntityBuildTokens) -> IDCard {
//         // 1. 取得 Entity 平台以進行 spawn
//         guard let entities = self.entities else {
//             fatalError("Platform Entities not found during build phase")
//         }
        
//         // 2. 生成一個新的實體 ID
//         let newEid = entities.spawn(1)[0]
//         var item_rids: [IDItem] = []

//         // 3. 遍歷 tokens 中的需求與對應的 rids
//         for (index, item) in tokens.manifest.requirements.enumerated() {
//             let rid = tokens.rids[index]
//             switch item {
//             case .Public_Component: item_rids.append( .Public( rid ) )
//             case .Private_Component: item_rids.append( .Private( rid ))
//             case .Phantom: item_rids.append( .Phantom( rid ))
//             }
            
//             let meta = (type: item.componentType, instance: item.factory)
//             // 4. 取得對應的 Storage 並存入實例
//             guard let storage = self.rawGetStorage(for: rid) else {
//                 fatalError("Storage missing for rid=\(rid.id), type=\(meta.type)")
//             }

//             if let fn = meta.instance {
//                 storage.rawAdd(eid: newEid, component: fn())
//             }
//         }
        
//         return IDCard(
//             eid: newEid,
//             manifest: tokens.manifest,
//             rids: tokens.rids,
//             itemRids: item_rids,
//             ridToAt: tokens.ridToAt
//         )
//     }
// }


// final class Proxy {
//     fileprivate let idcard: IDCard
//     unowned fileprivate let _base: BasePlatform
//     private(set) var maxRid: Int

//     init(idcard: IDCard, _base: BasePlatform) {
//         self.idcard = idcard
//         self._base = _base
//         self.maxRid = Self.maxRid(idcard: idcard)
//     }
    
//     @inline(__always)
//     private func checkAt(_ at: Int) {
//         precondition(at >= 0 && at < idcard.itemRids.count, "Proxy.get(at:) out of range: \(at)")
//     }

//     @inlinable
//     func get<T: Component>(at: Int) -> T? {
//         guard _base.entities!.isValid(idcard.eid) else {
//             fatalError("Logic Error: try to access a dead (Entity \(idcard.eid))!")
//         }
//         checkAt(at)
//         let item = idcard.itemRids[at]
//         switch item {
//         case .Private, .Phantom:
//             return nil
//         case .Public(let rid):
//             return _base.rawGetStorage(for: rid)!.get(idcard.eid) as? T
//         }
//     }

//     @inlinable
//     func get(at: Int) -> (any Component)? {
//         guard _base.entities!.isValid(idcard.eid) else {
//             fatalError("Logic Error: try to access a dead (Entity \(idcard.eid))!")
//         }
//         checkAt(at)
//         let item = idcard.itemRids[at]
//         switch item {
//         case .Private, .Phantom:
//             return nil
//         case .Public(let rid):
//             return _base.rawGetStorage(for: rid)!.get(idcard.eid) as? any Component
//         }
//     }

//     static private func maxRid(idcard: IDCard) -> Int {
//         var max = 0
//         for rid in idcard.rids {
//             max = rid.id > max ? rid.id : max
//         }
//         return max
//     }

//     fileprivate func ridToAt(_ targetRid: RegistryId) -> Int? {
//         return idcard.ridToAt[targetRid.id]
//     }

//     fileprivate var registry: Platform_Registry {
//         _base.registry!
//     }
// }

// extension BasePlatform {
//     @inlinable
//     func isValid(eid: EntityId) -> Bool {
//         let entities = self.entities!
//         return entities.isValid(eid)
//     }

//     func createProxy(idcard: IDCard) -> Proxy
//     {
//         guard isValid(eid: idcard.eid) else {
//             fatalError("invalid idCard in create proxy phase")
//         }

//         return Proxy(idcard: idcard, _base: self)
//     }
// }


// final class Sub_BasePlatform: BasePlatform {
//     private let proxy: Proxy
    
//     init(proxy: Proxy) {
//         self.proxy = proxy
//         super.init()

//         // check it has Platform Entites to manage its slots
//         var hasEntity: Bool = false
//         var hasRegistry: Bool = false

//         for manifest_item in proxy.idcard.manifest.requirements {
//             let componentType = manifest_item.componentType
//             if componentType is Platform_Entity.Type {
//                 hasEntity = true
//             }
//             else if componentType is Platform_Registry.Type {
//                 hasRegistry = true
//             } 
//         }

//         guard hasEntity else {
//             fatalError("need Platform_Entity for manage its slot")
//         }

//         guard !hasRegistry else {
//             fatalError("sub platform cannot has any Platform_Registry Type")
//         }

//         guard proxy.idcard.ridToAt[1] != nil else {
//             fatalError("sub platform needs to use the same type entites to main platform")
//         }

//         let eid0 = EntityId(id: 0, version: 0)
//         var rawStorage: [AnyPlatformStorage?] = []
//         rawStorage.append(contentsOf: repeatElement(nil, count: proxy.maxRid + 1))

//         // this is the boot for sub-platform
//         for (at, ele) in proxy.idcard.itemRids.enumerated() {
//             var componentType: any Component.Type
//             switch ele {
//             case .Public,
//                  .Phantom:
//                 // not private type
//                 componentType = proxy.idcard.manifest.requirements[at].componentType
//             case .Private:
//                 continue
//             }

//             // not private type
//             let rid = proxy.idcard.rids[at]

//             // [修正點]: 只有當這個位置還是 nil 時才建立新的 Storage
//             // 如果之前的 Storage Component 已經填過了，這裡就跳過，防止覆蓋
//             if rawStorage[rid.id] == nil {
//                 // here is public
//                 // maxRid + 1 gaurantee that insert is valid
//                 rawStorage[rid.id] = componentType.createPFStorage()
//             }

//             if let comp = proxy.get(at: at) {

//                 // store comp to storage
//                 rawStorage[rid.id]!.rawAdd(eid: eid0, component: comp)
                
//                 // check if it is a storage
//                 if let storageProvider = comp as? StorageTypeProvider {
//                     let innerType = storageProvider.storedComponentType
                    
//                     guard proxy.registry.contains(innerType) else {
//                         fatalError("not registry for T:(\(innerType)) means does not need st<T> component")
//                     }
//                     let innerTypeRid = proxy.registry.register(innerType)

//                     guard proxy.ridToAt(innerTypeRid) != nil else {
//                         fatalError("not apply for T:(\(innerType)) means does not need st<T> component")
//                     }

//                     guard rawStorage[innerTypeRid.id] == nil else {
//                         fatalError("please change the order on manifest. make sure st<\(innerType)> place is before then \(innerType)")
//                     }
                    
//                     let storage = comp as! AnyPlatformStorage
//                     rawStorage[innerTypeRid.id] = storage
//                 }
//             }
            
//             // phantom type do not need to do anything
//         }

//         // insert Proxy_Registry to Sub_PF
//         let storage = Proxy_Registry.createPFStorage() as! PFStorage<Proxy_Registry>
//         storage.add(eid: EntityId(id: 0, version: 0), component: Proxy_Registry(proxy: proxy))

//         rawStorage[0] = storage
        
//         // put rawStorages to self.storages
//         self.storages = rawStorage

//         // now we can spawn our eid0
//         // please confirm the type that main_pf_entities.Type == sub_pf_entitiese.Type
//         precondition(eid0 == self.entities!.spawn(1)[0], "should be Eid(id: 0, ver: 0)")

//         // boot is finised
//     }
// }


// final class Proxy_Registry: Platform_Registry, Component {
//     unowned private let proxy: Proxy

//     init(proxy: Proxy) {
//         self.proxy = proxy
//     }

//     // proxy can not register new type
//     func register(_ type: any Any.Type) -> RegistryId {
//         guard let registry = proxy._base.registry else {
//             fatalError("the host of the proxy dead")
//         }

//         guard registry.contains(type) else {
//             fatalError("proxy can not register new type")
//         }

//         let rid =  registry.register(type)
//         guard proxy.ridToAt(rid) != nil else {
//             fatalError("proxy does not has this manifest type")
//         }

//         return rid
//     }

//     func contains(_ type: any Any.Type) -> Bool {
//         guard let registry = proxy._base.registry else {
//             fatalError("the host of the proxy dead")
//         }
//         guard registry.contains(type) else {
//             return false
//         }
        
//         let rid = registry.register(type)
//         guard let at = proxy.ridToAt(rid) else {
//             return false
//         }

//         switch proxy.idcard.itemRids[at] {
//         case .Public, .Phantom:
//             return true
//         case .Private:
//             return false
//         }
//     }

//     var count: Int {
//         proxy.idcard.rids.count
//     }

//     static func createPFStorage() -> any AnyPlatformStorage {
//         return PFStorage<Proxy_Registry>()
//     }

//     func isReadable(_ type: any Any.Type) -> Bool {
//         guard let registry = proxy._base.registry else {
//             fatalError("the host of the proxy dead")
//         }
//         guard registry.contains(type) else { return false }

//         let rid = registry.register(type)
//         guard let at = proxy.ridToAt(rid) else { return false }

//         if case .Public = proxy.idcard.itemRids[at] { return true }
//         return false
//     }
// }