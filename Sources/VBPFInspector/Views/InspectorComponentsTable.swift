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
                
                Table(rts) {
                    // 第一欄：顯示 ID
                    TableColumn("RID") { row in
                        Text("\(row.id.id)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 50, max: 80) // 限制 ID 欄位寬度
                    
                    // 第二欄：顯示型別名稱
                    TableColumn("Component Type Name") { row in
                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.accentColor)
                            Text(row.typeName)
                                .fontWeight(.medium)
                        }
                    }
                }

            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("waiting world load")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            
        }
    }
}
