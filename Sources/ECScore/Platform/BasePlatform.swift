class BasePlatform : Platform {
    var storages: [AnyPlatformStorage?] = []

    func rawGetStorage(for rid: RegistryId) -> AnyPlatformStorage? {
        guard rid.id >= 0 && rid.id < storages.count else { return nil }
        return storages[rid.id]
    }
}

enum ManifestItem {
    case Public_Component( (Component.Type, (() -> any Component) ) )
    case Private_Component( (Component.Type, (() -> any Component) ) )
}

struct Manifest {
    let requirements: [ ManifestItem ]
}

extension ManifestItem {
    // 統一提取型別與實例/工廠函數
    var componentMetadata: (type: any Component.Type, instance: (() -> any Component) ) {
        switch self {
        case .Public_Component(let (type, c)),
             .Private_Component(let (type, c)):
            return (type, c)
        }
    }
}

struct EntityBuildTokens {
    fileprivate let manifest: Manifest
    let rids: [RegistryId]
}

enum IDItem {
    case Public(RegistryId)
    case Private(RegistryId)
}

struct IDCard {
    let eid: EntityId
    fileprivate let rids: [IDItem]
}

extension BasePlatform {
    func interop(manifest: Manifest) -> EntityBuildTokens {
        guard let registry = registry else {
            fatalError("Platform Registry not found during interop phase")
        }
        var rids: [RegistryId] = []
        var newTypes: [any Component.Type] = []

        for item in manifest.requirements {
            let meta = item.componentMetadata
            if !registry.contains(meta.type) {
                newTypes.append(meta.type)
            }

            let rid = registry.register(meta.type)
            rids.append(rid)
        }
        // prepare to build storage
        Self.ensureStorageCapacity(base: self)
        // storages length is ensured
        for newT in newTypes {
            let newT_storage =  openAndCreateStorage(newT)
            let rid = registry.register(newT)
            self.storages[rid.id] = newT_storage
        }

        return EntityBuildTokens(manifest: manifest, rids: rids)
    }

    private static func ensureStorageCapacity(base: BasePlatform) {
        let registry = base.registry! // check while interop start
        let rid_count = registry.count
        let needed = rid_count - base.storages.count
        
        if needed > 0 {
            base.storages.append( contentsOf: repeatElement(nil, count: needed) )
        }
    }

    private func openAndCreateStorage(_ type: any Component.Type) -> any AnyPlatformStorage {
        func helper<T: Component>(_ concreteType: T.Type) -> any AnyPlatformStorage {
            return T.createPFStorage()
        }
        return helper(type)
    }
    
}

extension BasePlatform {
    /// 根據 tokens 真正建立實體並填入組件
    func build(from tokens: EntityBuildTokens) -> IDCard {
        // 1. 取得 Entity 平台以進行 spawn
        guard let entities = self.entities else {
            fatalError("Platform Entities not found during build phase")
        }
        
        // 2. 生成一個新的實體 ID
        let newEid = entities.spawn(1)[0]
        var rids: [IDItem] = []

        // 3. 遍歷 tokens 中的需求與對應的 rids
        for (index, item) in tokens.manifest.requirements.enumerated() {
            let rid = tokens.rids[index]
            switch item {
            case .Public_Component: rids.append( .Public( rid ) )
            case .Private_Component: rids.append( .Private( rid ))
            }
            
            let meta = item.componentMetadata
            // 4. 取得對應的 Storage 並存入實例
            guard let storage = self.rawGetStorage(for: rid) else {
                fatalError("Storage missing for rid=\(rid.id), type=\(meta.type)")
            }
            storage.rawAdd(eid: newEid, component: meta.instance())
        }
        
        return IDCard(eid: newEid, rids: rids)
    }
}


// extension BasePlatform {

//     // MARK: - World Inspector (入口)
    
//     func inspectWorld() {
//         print("\n🌍 [World Inspector] Start Scanning...")
//         print("========================================")
        
//         // 1. 取得實體管理器
//         guard let entityPF = self.entities as? EntitiyPlatForm_Ver0 else {
//             print("❌ Entity Platform not found.")
//             return
//         }
        
//         // 2. 遍歷所有實體
//         var activeCount = 0
//         entityPF.forEachLiveId { eid in
//             // 對每個實體執行詳細檢查
//             if self.inspect(eid: eid) {
//                 activeCount += 1
//             }
//         }
        
//         print("========================================")
//         print("📊 Total Active Entities with Components: \(activeCount)")
//         print("🌍 [World Inspector] Scan Complete.\n")
//     }

//     // MARK: - Single Entity Inspector (邏輯核心)

//     /// 檢查單一實體，若該實體持有任何組件回傳 true，否則 false
//     @discardableResult
//     func inspect(eid: EntityId) -> Bool {
//         var foundComponents: [String] = []
//         var outputBuffer = "" // 先寫入 buffer，確認有東西再印，保持版面乾淨

//         outputBuffer += "🕵️‍♂️ Entity [\(eid.id)]\n"
        
//         // 遍歷所有倉庫
//         for (rid_index, storage) in storages.enumerated() {
//             guard let storage = storage else { continue }
            
//             // 檢查該 Storage 是否持有此 Entity
//             if storageIsOccupied(storage, by: eid) {
//                 // 取得型別名稱與可見性
//                 let typeName = getTypeName(for: rid_index) ?? "Unknown(\(rid_index))"
//                 let visibility = isPrivate(rid_index) ? "🔒 Private" : "🌍 Public"
                
//                 outputBuffer += "   ├─ [RID:\(rid_index)] \(typeName) \(visibility)\n"
//                 foundComponents.append(typeName)
//             }
//         }
        
//         // 只有當實體真的有掛載組件時，才印出來 (過濾掉空號)
//         if !foundComponents.isEmpty {
//             print(outputBuffer)
//             return true
//         }
        
//         return false
//     }
    
//     // MARK: - Helpers
    
//     private func storageIsOccupied(_ storage: any AnyPlatformStorage, by eid: EntityId) -> Bool {
//         // 假設 AnyPlatformStorage 或是其具體實作有 get 方法
//         // 這裡做一個轉型嘗試，因為 protocol 定義中可能只有 rawAdd/remove
//         // 你需要確保 storage 實作了查詢介面
//         if let specificStorage = storage as? PFStorage<RegistryPlatform> { // 舉例
//              return specificStorage.get(eid) != nil
//         }
        
//         // 通用解法：利用 AnyPlatformStorage 的擴充或反射
//         // ⚠️ 你的 Platform.swift 需要確保有讀取介面
//         return storage.get(eid) != nil 
//     }
    
//     private func getTypeName(for rid: Int) -> String? {
//         // 嘗試從 Registry 撈名字
//         guard let registry = self.registry as? RegistryPlatform else { return nil }
        
//         // ⚠️ 這需要你在 RegistryPlatform 加一個字典 [Int: String] 來存名字
//         // return registry.getTypeName(by: rid)
        
//         // 暫時的 fallback，如果 Registry 是 ID 0
//         if rid == 0 { return "RegistryPlatform" }
//         if rid == 1 { return "Platform_Entitiy" }
//         return nil
//     }
    
//     private func isPrivate(_ rid: Int) -> Bool {
//         // 這裡未來可以對接你的 IDCard 權限表
//         return false
//     }
// }