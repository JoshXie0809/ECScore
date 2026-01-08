import Testing
@testable import ECScore

@Test func registryTest() async throws {
    let registryPf = RegistryPlatform()

    #expect(registryPf.register(RegistryPlatform.self).id == 0)   
}

@Test func registryTest2() async throws {
    let registryPf = RegistryPlatform()

    let registry =  registryPf.registry

    #expect(registry != nil)
    let registryNotNil = registry!

    #expect(registryNotNil === registryPf)
}

@Test func bootTest() async throws {
    let base_pf = BasePlatform()
    let r_pf = RegistryPlatform()
    let e_pf = EntitiyPlatForm_Ver0()

    base_pf.boot(registry: r_pf, entities: e_pf)
}