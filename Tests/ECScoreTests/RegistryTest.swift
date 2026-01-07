import Testing
@testable import ECScore

@Test func registryTest() async throws {
    let registryPf = RegistryPlatform()

    #expect(registryPf.registry(RegistryPlatform.self).id == 0)   
}