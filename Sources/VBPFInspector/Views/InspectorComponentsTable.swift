import ECScore
import SwiftUI

struct ComponentTypeRow: Identifiable {
    let id: RegistryId      // 使用 RegistryId 作為唯一識別碼
    let typeName: String    // 顯示用的型別名稱
}

struct InspectorComponentsTable: View {
    
    var world: GameWorld? {
        InspectorDelegate.shared?.world
    }
    
    func registeredComponents(_ registry: any Platform_Registry) -> [ComponentTypeRow]
    {
        
        let entries = registry.giveAllRigsterTypes()
                
        return entries.map { (rid, type) in
            ComponentTypeRow(
                id: rid,
                typeName: String(describing: type) // 或者使用 type.typeIdString 如果該協議有定義
            )
        }.sorted { $0.id < $1.id } // 排序讓列表顯示穩定
    }
        
    var body: some View {
        let _ = InspectorDelegate.shared?.refreshTrigger
        
        VStack {
            if let gw = world {
                // 取得目前 registry 中的實體總數
                let registry = gw.base.registry
                let componentTypeCount = registry.maxRidId + 1

                Text("Component Type 數目: \(componentTypeCount)")
                    .font(.headline)
                
                let rts = registeredComponents(registry)
                
                // 使用 List 或 ScrollView 搭配 ForEach 來顯示
                List {
                    // SwiftUI 需要 ForEach 來根據數量產生 View
                    ForEach(rts) { row in
                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.accentColor)
                            
                            Text("[\(row.id.id)]")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Text(row.typeName)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                    }
                }

            } else {
                Text("waiting world load")
            }
            
        }
    }
}
