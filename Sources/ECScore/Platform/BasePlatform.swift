class BasePlatform : Platform {
    var storages: [PlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> PlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}


extension Platform {
    /// 嘗試從平台中取得地圖（握手）
    var registry: RegistryPlatform? {
        // 直接找 0 號位並嘗試轉型
        let rid0 = EntityId(id: 0, version: 0)
        let storage = self.rawGetStorage(for: rid0) as? Storage<RegistryPlatform>
        return storage?.getEntity(rid0)
    }
}


