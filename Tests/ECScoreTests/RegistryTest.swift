import Testing
@testable import ECScore

@Test func registryTest() async throws {
    let registryPf = RegistryPlatform()

    #expect(registryPf.registry(RegistryPlatform.self).id == 0)   
}

@Test func registryTest2() async throws {
    let registryPf = RegistryPlatform()

    let registry =  registryPf.registry

    #expect(registry != nil)
    let registryNotNil = registry!

    #expect(registryNotNil === registryPf)
}