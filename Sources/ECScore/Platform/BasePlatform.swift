class BasePlatform : Platform {
    var storages: [AnyPlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> AnyPlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}



