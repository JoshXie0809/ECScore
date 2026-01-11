import Testing
@testable import ECScore

@Test func dataPF_Proxy() async throws {
    let base = BasePlatform()
    let registry = RegistryPlatform()
    let entities = EntitiyPlatForm_Ver0()
    base.boot(registry: registry, entities: entities)

    let fnC = {
        return PFStorage<Position>()
    }

    let manifest = Manifest(requirements: [
        .Public_Component(( (PFStorage<Position>).self, fnC))
    ])

    // 2. 執行 Interop (準備環境)
    let tokens = base.interop(manifest: manifest)
    // // // 3. 執行 Build (產生實體)
    let idcard = base.build(from: tokens)

    let a = {
        let proxy = base.createProxy(idcard: idcard)
        let val: PFStorage<Position> = proxy.get(at: 0)
        // add an entity
        val.add(eid: EntityId(id: 23, version: 0), component: Position(x: 1.0, y: 2.0) )
        #expect(type(of: val) == PFStorage<Position>.self)
    }

    a()

    let nested_st = base.rawGetStorage(for: tokens.rids[0])?.get(EntityId(id: 1, version: 0)) as! PFStorage<Position>
    let val = nested_st.get(EntityId(id: 23, version: 0)) as! Position
    #expect(val.x == 1.0 && val.y == 2.0 )
}