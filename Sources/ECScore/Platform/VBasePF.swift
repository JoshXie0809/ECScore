public extension Validated<BasePlatform, Proof_Handshake, Platform_Facts> {
    @inlinable
    var registry: any Platform_Registry {
        value.storages[PlatformReservedSlot.registry.rawValue]!.get(EntityId(id: 0, version: 0)) as! Platform_Registry
    }
    
    @inlinable
    var entities: any Platform_Entity {
        value.storages[PlatformReservedSlot.entities.rawValue]!.get(EntityId(id: 0, version: 0)) as! Platform_Entity
    }

    fileprivate func mount(rid: RegistryId, storage: AnyPlatformStorage) {
        value.storages[rid.id] = storage
    }

    fileprivate func ensureStorageCapacity() {
        let rid_count = registry.count
        let needed = rid_count - value.storages.count
        
        if needed > 0 {
            value.storages.append( contentsOf: repeatElement(nil, count: needed) )
        }
    }

    @inlinable
    func spawnEntity(_ n: Int = 1) -> [EntityId]
    {
        return entities.spawn(n)
    }

    @inlinable
    func getStorage<C: Component>(token: TypeToken<C>) -> PFStorageBox<C> {
        value.storages[token.rid.id] as! PFStorageBox<C>
    }
}

// 向 main base-pf 確保需要的 Type 的 storage 是存在的
public typealias ComponentManifest = Array<any Component.Type>

public struct InteropTokens {
    let rids: [RegistryId]
    let idToAt: [ObjectIdentifier:Int]
    fileprivate init(
        rids: [RegistryId],
        idToAt: [ObjectIdentifier:Int]
    ) {
        self.rids = rids
        self.idToAt = idToAt
    }

    func getRid(_ type: Any.Type) -> RegistryId? {
        guard let at = idToAt[ObjectIdentifier(type)] else { return nil }
        return rids[at]
    }
}

@discardableResult
public func interop(
    _ pf_val: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ manifest_val: consuming Validated<ComponentManifest, Proof_Ok_Manifest, Manifest_Facts>
)
    -> InteropTokens
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
        // search registry rid, because registered before, not nil
        let rid = registry.lookup(type._hs)!
        rids.append(rid)
        let type_id = ObjectIdentifier(type)
        idToAt[type_id] = at
    }

    let pendingMounts = newRids.map { (rid, type) in
        return (rid, type.createPFStorage())
    }

    pf_val.ensureStorageCapacity()

    for (rid, storage) in pendingMounts {
        pf_val.mount(rid: rid, storage: storage)
    }

    // // ensure storages length
    // pf_val.ensureStorageCapacity()

    // for (rid, type) in newRids {
    //     pf_val.mount(rid: rid, storage: type.createPFStorage())
    // }

    return InteropTokens(rids: rids, idToAt: idToAt)
}

public struct TypeToken<T: Component> {
    public let rid: RegistryId
    fileprivate init(rid: RegistryId) { self.rid = rid}
    var type: T.Type { T.self }
}

public func interop<each T: Component>(
    _ pf_val: borrowing Validated<BasePlatform, Proof_Handshake, Platform_Facts>,
    _ type: repeat (each T).Type
) 
    -> (repeat TypeToken<each T>)
{
    var manifest: ComponentManifest = []
    repeat manifest.append(each type)
    var manifest_val = Raw(value: manifest).upgrade(Manifest_Facts.self)
    
    guard validate(validated: &manifest_val, .unique)
    else {
        fatalError("duplicate of type while interop<each T>")
    }
    
    var env = Manifest_Facts.Env._default(); env.registry = pf_val.registry;
    
    guard validate(
        validated: &manifest_val, 
        other_validated_resource: env, 
        .noTypeStringCollisoin
    ) else {
        fatalError("TypeString hashed value collision while interop<each T>")
    }

    guard case let .success(ok_manifest) = manifest_val.certify(Proof_Ok_Manifest.self) 
    else {
        fatalError("unreachable error while interop<each T>")
    }

    let tokens = interop(pf_val, ok_manifest)
    return ( repeat TypeToken(rid: tokens.getRid(each type)!) )
}

// utils: make a booted base pf
public func makeBootedPlatform() -> Validated<BasePlatform, Proof_Handshake, Platform_Facts> {
    let base = BasePlatform()
    let registry = RegistryPlatform()
    let entities = EntityPlatForm_Ver0()
    
    base.boot(registry: registry, entities: entities)

    var pf_val = Raw(value: base).upgrade(Platform_Facts.self)
    validate(validated: &pf_val, .handshake)

    guard case let .success(pf_handshake) = pf_val.certify(Proof_Handshake.self) else {
        fatalError("error while booted platform")
    }

    return pf_handshake
}

