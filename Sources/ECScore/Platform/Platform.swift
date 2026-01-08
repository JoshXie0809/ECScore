protocol Platform {
    func rawGetStorage(for id : RegistryId) -> AnyPlatformStorage?
}

protocol AnyPlatformStorage {
    mutating func remove(eid: EntityId)
    
}