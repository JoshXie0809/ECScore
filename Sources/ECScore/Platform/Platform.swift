protocol Platform {
    var entities: Entities { get }
    func getStorage(for id : RegistryId) -> PlatformStorage?
}

protocol PlatformStorage {

}



class BasePlatform : Platform {
    var storages: [PlatformStorage?] = []
    let entities = Entities()

    func getStorage(for rid: RegistryId) -> PlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }

    // 取得或建立強型別儲存空間
    final func getStorage<T: Component>(rid: RegistryId) -> Storage<T> {
        let index = rid.id // 拿身分證上的數字去排隊
        
        if index >= storages.count {
            let needed = index - storages.count + 1
            storages.append(contentsOf: [PlatformStorage?](repeating: nil, count: needed))
        }

        if let existing = storages[index] {
            return existing as! Storage<T>
        } else {
            let newS = Storage<T>()
            storages[index] = newS
            return newS
        }
    }
}

