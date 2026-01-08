class BasePlatform : Platform {
    var storages: [PlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> PlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}



