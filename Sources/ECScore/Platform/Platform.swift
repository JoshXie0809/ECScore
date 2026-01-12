protocol Platform {
    func rawGetStorage(for id : RegistryId) -> AnyPlatformStorage?
}

extension Platform {
    func rawGetStorage(for id : RegistryId) -> AnyPlatformStorage? {
        return nil
    }
}

protocol AnyPlatformStorage {
    mutating func remove(eid: EntityId)
    func rawAdd(eid: EntityId, component: Any)
    static var valueType: any Component.Type { get }
    func getWithDenseIndex_Uncheck(_ index: Int) -> Any?
    func get(_ eid: EntityId) -> Any?

}
