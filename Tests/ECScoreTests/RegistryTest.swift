import Testing
@testable import ECScore

@Test func registryTest() async throws {
    let registryPf = RegistryPlatform()

    #expect(registryPf.register(RegistryPlatform.self).id == 0)   
}

@Test func bootTest() async throws {
    let base_pf = BasePlatform()
    let r_pf = RegistryPlatform()
    let e_pf = EntitiyPlatForm_Ver0()

    base_pf.boot(registry: r_pf, entities: e_pf)

    guard let registry = base_pf.registry as? RegistryPlatform else {
        fatalError("regitry not find!!")
    }

    #expect(registry.register(RegistryPlatform.self).id == 0)
    #expect(registry.register(EntitiyPlatForm_Ver0.self).id == 1)

    _ = registry.register(Position.self)

    #expect(registry.register(Position.self).id == 2)

    // get myself
    guard let entityPF_from_registry = base_pf.entities as? EntitiyPlatForm_Ver0

    else {
        fatalError("entities not find")
    }

    #expect(entityPF_from_registry === e_pf)
}