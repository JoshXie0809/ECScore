
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