// import Testing
// @testable import ECScore

// @Test func dataPF_Proxy() async throws {
//     let base = BasePlatform()
//     let registry = RegistryPlatform()
//     let entities = EntityPlatForm_Ver0()
//     base.boot(registry: registry, entities: entities)

//     let fnC = {
//         return PFStorage<Position>()
//     }

//     let fnE = {
//         return EntityPlatForm_Ver0() 
//     }

//     let manifest = Manifest(requirements: [
//         // 維持好 data storage and data type 的順序
//         .Public_Component((PFStorage<Position>.self, fnC)),
//         .Public_Component((EntityPlatForm_Ver0.self, fnE)),
//         // 暫時懶得改
//         .Phantom(Position.self),

//     ])

//     // 2. 執行 Interop (準備環境)
//     let tokens = base.interop(manifest: manifest)
//     // // // 3. 執行 Build (產生實體)
//     let idcard = base.build(from: tokens)
//     print(tokens.rids)

//     let a = {
//         let proxy = base.createProxy(idcard: idcard)
//         let pfs: PFStorage<Position> = proxy.get(at: 0)!
//         // add an entity
//         pfs.add(eid: EntityId(id: 23, version: 0), component: Position(x: 1.0, y: 2.0) )
//         #expect(type(of: pfs) == PFStorage<Position>.self)
//     }

//     a()

//     // using raw api is really awful

//     // let nested_st = base.rawGetStorage(for: tokens.rids[0])?.get(EntityId(id: 1, version: 0)) as! PFStorage<Position>
//     // let val = nested_st.get(EntityId(id: 23, version: 0)) as! Position
//     // #expect(val.x == 1.0 && val.y == 2.0 )
// }


// @Test func proxyAsPlatform() async throws {
//     let base = BasePlatform()
//     let registry = RegistryPlatform()
//     let entities = EntityPlatForm_Ver0()
//     base.boot(registry: registry, entities: entities)

//     let fnC = {
//         return PFStorage<Position>()
//     }

//     let fnE = {
//         return EntityPlatForm_Ver0() 
//     }

//     let manifest = Manifest(requirements: [
//         // Storage Type
//         .Public_Component((EntityPlatForm_Ver0.self, fnE)),
//         .Public_Component((PFStorage<Position>.self, fnC)),
//         // Data Type
//         .Phantom(Position.self),
//     ])

//     // 2. 執行 Interop (準備環境)
//     let tokens = base.interop(manifest: manifest)
//     // // // 3. 執行 Build (產生實體)
//     let idcard = base.build(from: tokens)
    
//     let proxy = base.createProxy(idcard: idcard)
//     let proxy_base_pf = proxy.asBasePlatform()!
    
//     #expect(proxy_base_pf.storages.count == 4)
//     #expect(proxy_base_pf.entities != nil) 
//     #expect(proxy_base_pf.registry != nil) // use the proxy as registry

//     let eid0_position_storage = proxy_base_pf.storages[2]?.get(EntityId(id: 0, version: 0)) as! PFStorage<Position>
//     let proxy_base_pf_storage_position = proxy_base_pf.storages[3] as! PFStorage<Position>
    
//     #expect( eid0_position_storage.self  === proxy_base_pf_storage_position.self)

//     let sub_pf_registry = proxy_base_pf.registry! as? Proxy_Registry
//     #expect(sub_pf_registry != nil)

// }

