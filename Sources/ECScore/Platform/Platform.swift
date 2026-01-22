protocol Platform {
    func rawGetStorage(for id : RegistryId) -> AnyPlatformStorage?
}

extension Platform {
    func rawGetStorage(for id : RegistryId) -> AnyPlatformStorage? {
        return nil
    }
}

protocol AnyPlatformStorage: ~Copyable {
    mutating func remove(eid: EntityId)
    mutating func rawAdd(eid: EntityId, component: Any)

    func getWithDenseIndex_Uncheck(_ index: Int) -> Any?
    func get(_ eid: EntityId) -> Any?

    var storageType: any Component.Type { get }
}
